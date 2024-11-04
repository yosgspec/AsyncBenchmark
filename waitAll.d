import std.stdio;
import std.format;
import std.concurrency;
import std.array;
import std.range;
import std.parallelism;
import std.conv;
import std.datetime.stopwatch;
import std.algorithm;
import std.algorithm.iteration;
import core.thread;
import std.typecons;

/// たらい回し関数
int tarai(int x,int y,int z){return x<=y? y: tarai(tarai(x-1,y,z),tarai(y-1,z,x),tarai(z-1,x,y));}
/// フィボナッチ関数
int fib(int n) {return n<2? n: fib(n-1)+fib(n-2);}
/// タイマーの経過時間
float function(StopWatch) getTick = t=>t.peek.total!"msecs"*1e-3;

/// テスト関数
string[] myFunc(string taskName, ulong i, int v, StopWatch timer){
	double[] ticks;
	double[] spans;
	ticks ~= getTick(timer);
	Thread.sleep(v*100.msecs);
	ticks ~= getTick(timer);
	spans ~= ticks[$ - 1] - ticks[$ - 2];
	tarai(12, 6, 0);
	ticks ~= getTick(timer);
	spans ~= ticks[$-1]-ticks[$-2];
	int fibResult = fib(30+v);
	ticks ~= getTick(timer);
	spans ~= ticks[$-1] - ticks[$-2];
	return ["D", taskName, to!string(i), to!string(v), to!string(fibResult)]~(ticks~spans).map!(t => format("%.3f", t)).array;
}
/// テスト関数
void myFuncRefs(string[][] result, string taskName, ulong i, int v, StopWatch timer){
	result[i] = myFunc(taskName, i, v, timer);
}
/// テスト関数
void myFuncSender(string taskName, ulong i, int v, StopWatch timer){
	ownerTid.send(i, cast(immutable(char[])[])myFunc(taskName, i, v, timer));
}

/// 同期タスク
string[][] syncAll(string taskName, int[] values, StopWatch timer){
	return iota(values.length).map!(i=>myFunc(taskName, i, values[i], timer)).array;
}

/// [欠陥品]非同期タスク(低水準スレッド)
string[][] threadAll(string taskName, int[] values, StopWatch timer){
	auto result = new string[][](values.length);
	auto threads=new ThreadGroup();
	foreach(i, v; values) {
		auto thread = new Thread(() => myFuncRefs(result, taskName, i, v, timer));
		thread.start();
		threads.add(thread);
	}
	threads.joinAll;
	return result;
}

/// 非同期タスク(パラレル)
string[][] parallelAll(string taskName, int[] values, StopWatch timer){
	auto result = new string[][](values.length);
	foreach(i, v; parallel(values)){
		myFuncRefs(result, taskName, i, v, timer);
	}
	return result;
}

/// 非同期タスク(メッセージパッシング(スレッド))
string[][] spawnAll(string taskName, int[] values, StopWatch timer){
	auto result = new string[][](values.length);
	auto spawns = iota(values.length).map!(i=>spawn(&myFuncSender, taskName, i, values[i], timer)).array;
	foreach(i; iota(spawns.length)){
		receive((ulong i, immutable(char[])[] res){
			result[i] = cast(string[])res;
		});
	}
	return result;
}

/// メイン処理
void main() {
	auto result = [["#Lang", "Task", "Index", "Value", "Result", "Start", "Sleeped", "Taraied", "Fibed", "SleepTime", "TaraiTime", "FibTime"]];
	int[] values = array(iota(10, 0, -1));
	alias Task = tuple!("Name", "Fn");
	auto tasks = [
		Task("sync", &syncAll),
		//Task("thread", &threadAll),
		Task("parallel", &parallelAll),
		Task("spawn", &spawnAll),
	];

	foreach(task; tasks){
		writef("!%s: ", task.Name);
		stdout.flush();
		auto timer = StopWatch();
		timer.start();
		result ~= task.Fn(task.Name, values, timer);
		writef("%.3f\n", getTick(timer));
	}
	writeln(result.map!(row=>row.join("\t")).join("\n"));
}
