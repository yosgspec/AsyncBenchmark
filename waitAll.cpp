#include <cstdio>
#include <iostream>
#include <vector>
#include <thread>
#include <chrono>
#include <future>
#include <algorithm>
#include <string>
#include <numeric>
#include <execution>

using namespace std;
using namespace chrono;

/** @brief たらい回し関数 */
int tarai(int x,int y,int z){return x<=y? y: tarai(tarai(x-1,y,z),tarai(y-1,z,x),tarai(z-1,x,y));}
/** @brief フィボナッチ関数 */
int fib(int n){return n<2? n: fib(n-1)+fib(n-2);}
/** @brief タイマーの経過時間 */
double getTick(steady_clock::time_point start){return duration<double>(steady_clock::now()-start).count();}

/** @brief テスト関数 */
future<vector<string>> myFunc(string taskName, int i, int v, steady_clock::time_point timer){
	vector<double> ticks;
	vector<double> spans;
	ticks.push_back(getTick(timer));
	this_thread::sleep_for(milliseconds(v*100));
	ticks.push_back(getTick(timer));
	spans.push_back(ticks.back()-ticks[ticks.size()-2]);
	tarai(12, 6, 0);
	ticks.push_back(getTick(timer));
	spans.push_back(ticks.back()-ticks[ticks.size()-2]);
	auto fibResult = fib(30+v);
	ticks.push_back(getTick(timer));
	spans.push_back(ticks.back()-ticks[ticks.size()-2]);
	vector<string> result = {"C++", taskName, to_string(i), to_string(v), to_string(fibResult)};
	for(auto& vec: {&ticks, &spans}){
		for(auto& v: *vec){
			char buf[8];
			sprintf(buf, "%.3f", v);
			result.push_back(buf);
		}
	}
	return async(launch::async, [result](){return result;});
}
/** @brief テスト関数(同期) */
auto myFuncSync = [](string taskName, int i, int v, steady_clock::time_point timer){
    return myFunc(taskName, i, v, timer).get();
};

/** @brief 同期タスク */
vector<vector<string>> syncAll(string taskName, vector<int> values, steady_clock::time_point timer){
	vector<vector<string>> result;
	for(size_t i=0;i<values.size();i++)
		result.push_back(myFuncSync(taskName, i, values[i], timer));
	return result;
}

/** @brief 非同期タスク(マルチスレッド) */
vector<vector<string>> asyncAll(string taskName, vector<int> values, steady_clock::time_point timer){
	vector<future<vector<string>>> futures;
	for(size_t i=0;i<values.size();i++)
		futures.push_back(myFunc(taskName, i, values[i], timer));
	vector<vector<string>> result;
	for(auto& fut: futures) result.push_back(fut.get());
	return result;
}

/** @brief 非同期タスク(低水準スレッド) */
vector<vector<string>> threadAll(string taskName, vector<int> values, steady_clock::time_point timer){
	vector<vector<string>> result(values.size());
	vector<thread> threads;
	for(size_t i=0;i<values.size();i++){
		threads.emplace_back([&, i](){
			result[i] = myFuncSync(taskName, i, values[i], timer);
		});
	}
	for(auto& t: threads) t.join();
	return result;
}

/** @brief 非同期タスク(パラレル処理) */
vector<vector<string>> parallelAll(string taskName, vector<int> values, steady_clock::time_point timer){
	vector<vector<string>> result(values.size());
	for_each(execution::par, values.begin(), values.end(), [&](int v){
		size_t i = distance(values.begin(), find(values.begin(), values.end(), v));
		result[i] = myFuncSync(taskName, i, v, timer);
	});
	return result;
}

/** @brief メイン処理 */
int main(){
	vector<vector<string>> result = {{"#Lang", "Task", "Index", "Value", "Result", "Start", "Sleeped", "Taraied", "Fibed", "SleepTime", "TaraiTime", "FibTime"}};
	vector<pair<string, vector<vector<string>>(*)(string, vector<int>, steady_clock::time_point)>> tasks = {
		{"sync", &syncAll},
		{"async", &asyncAll},
		{"thread", &threadAll},
		{"parallel", &parallelAll}
	};
	vector<int> values(10);
	iota(values.begin(), values.end(), 1);
	reverse(values.begin(), values.end());
	steady_clock::time_point timer;
	for(const auto& task: tasks){
		const string& taskName = task.first;
		cout<<"!"<<taskName<<": "<<flush;
		vector<vector<string>>(*taskFunc)(string, vector<int>, steady_clock::time_point) = task.second;
		timer = steady_clock::now();
		auto taskResult = taskFunc(taskName, values, timer);
		result.insert(result.end(), taskResult.begin(), taskResult.end());
		printf("%.3f\n", getTick(timer));
	}
	string resultAll;
	for(size_t i=0;i<result.size();++i){
		if(0<i) resultAll+="\n";
		for(size_t n=0;n<result[i].size();++n){
			if(0<n) resultAll+="\t";
			resultAll+=result[i][n];
		}
	}
	cout<<resultAll<<endl;
	return 0;
}
