using System;
using System.Collections.Generic;
using System.Collections.Concurrent;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using System.Diagnostics;

/// <summary>たらい回し関数</summary>
Func<int,int,int,int> tarai = (x,y,z)=>x<=y? y: tarai(tarai(x-1,y,z),tarai(y-1,z,x),tarai(z-1,x,y));
/// <summary>フィボナッチ関数</summary>
Func<int,int> fib = n=>n<2? n: fib(n-1)+fib(n-2);
/// <summary>タイマーの経過時間</summary>
Func<Stopwatch,double> getTick = t=>t.ElapsedMilliseconds*1e-3;

/// <summary>テスト関数</summary>
async Task<string[]> myFunc(string taskName, int i, int v, Stopwatch timer){
	var ticks = new List<double>();
	var spans = new List<double>();
	ticks.Add(getTick(timer));
	await Task.Delay(v*100);
	ticks.Add(getTick(timer));
	spans.Add(ticks[^1]-ticks[^2]);
	tarai(12, 6, 0);
	ticks.Add(getTick(timer));
	spans.Add(ticks[^1]-ticks[^2]);
	var fibResult = fib(30+v);
	ticks.Add(getTick(timer));
	spans.Add(ticks[^1]-ticks[^2]);
	return new[]{"C#", taskName, $"{i}", $"{v}", $"{fibResult}"}.Concat(ticks.Concat(spans).Select(t=>$"{t:F3}")).ToArray();
}

/// <summary>同期タスク</summary>
async Task<List<string[]>> syncAll(string taskName, int[] values, Stopwatch timer){
	var result = new List<string[]>();
	for(var i=0;i<values.Length;i++) result.Add(await myFunc(taskName, i, values[i], timer));
	return result;
}

/// <summary>非同期タスク(マルチスレッド)</summary>
async Task<List<string[]>> asyncAll(string taskName, int[] values, Stopwatch timer){
	return (await Task.WhenAll(values.Select((v, i)=>myFunc(taskName, i, v, timer)))).ToList();
}

/// <summary>非同期タスク(低水準スレッド)</summary>
Task<List<string[]>> threadAll(string taskName, int[] values, Stopwatch timer) {
	var result = new ConcurrentDictionary<int, string[]>();
	values.Select((v, i)=>{
		var thread = new Thread(()=>{
			var index=i;
			result[index] = myFunc(taskName, i, v, timer).Result;
		});
		thread.Start();
		return thread;
	}).ToList().ForEach(thread=>thread.Join());
	return Task.FromResult(result.OrderBy(v=>v.Key).Select(v=>v.Value).ToList());
}

/// <summary>非同期タスク(パラレル処理)</summary>
Task<List<string[]>> parallelAll(string taskName, int[] values, Stopwatch timer){
	var result = new ConcurrentDictionary<int,string[]>();
	Parallel.For(0, values.Length, i=>{
		result[i] = myFunc(taskName, i, values[i], timer).Result;
	});
	return Task.FromResult(result.OrderBy(v=>v.Key).Select(v=>v.Value).ToList());
}

/// <summary>メイン処理</summary>
async Task main(){
	var result = new List<string[]>{new[]{"#Lang", "Task", "Index", "Value", "Result", "Start", "Sleeped", "Taraied", "Fibed", "SleepTime", "TaraiTime", "FibTime"}};
	var tasks = new (string, Func<string,int[],Stopwatch,Task<List<string[]>>>)[]{
		("sync", syncAll),
		("async", asyncAll),
		("thread", threadAll),
		("parallel", parallelAll),
	};
	var values = Enumerable.Range(1,10).Reverse();
	int ioMin;
	ThreadPool.GetMinThreads(out _, out ioMin);
	ThreadPool.SetMinThreads(values.Length, ioMin);
	foreach(var (taskName, task)  in tasks){
		var timer = Stopwatch.StartNew();
		result.AddRange(await task(taskName, values, timer));
		Console.WriteLine($"!{taskName}:{getTick(timer):F3}");
	}
	Console.WriteLine(String.Join("\n", result.Select(row=>String.Join("\t", row))));
}
main().Wait();