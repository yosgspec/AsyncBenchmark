"use strict";
const {Worker, isMainThread, parentPort, workerData} = require("worker_threads");
const cluster = require("cluster");

/** たらい回し関数 */
const tarai = (x,y,z)=>x<=y? y: tarai(tarai(x-1,y,z),tarai(y-1,z,x),tarai(z-1,x,y));
/** フィボナッチ関数 */
const fib = n=>n<2? n: fib(n-1)+fib(n-2);
/** タイマーの経過時間 */
const getTick = t=>(performance.now()-t)*1e-3;

/** テスト関数 */
async function myFunc(taskName, i, v, timer){
	const ticks = [];
	const spans = [];
	ticks.push(getTick(timer));
	await new Promise(res=>setTimeout(res, v*100));
	ticks.push(getTick(timer));
	spans.push(ticks.at(-1)-ticks.at(-2));
	tarai(12, 6, 0);
	ticks.push(getTick(timer));
	spans.push(ticks.at(-1)-ticks.at(-2));
	const fibResult = fib(30+v);
	ticks.push(getTick(timer));
	spans.push(ticks.at(-1)-ticks.at(-2));
	return ["JavaScript", taskName, ""+i, ""+v, ""+fibResult].concat(ticks.concat(spans).map(v=>v.toFixed(3)));
}
/** テスト関数(処理間通信) */
const myFuncSend = async(sender, ...args)=>sender(await myFunc(...args));

/** 同期タスク */
async function syncAll(taskName, values, timer){
	const result = [];
	for(let i=0;i<values.length;i++) result.push(await myFunc(taskName, i, values[i], timer));
	return result;
}

/** 非同期タスク(シングルスレッド) */
async function asyncAll(taskName, values, timer){
	return await Promise.all(values.map((v, i)=>myFunc(taskName, i, v, timer)));
}

/** 非同期タスク(非同期タイマー) */
async function timeoutAll(taskName, values, timer) {
	const result = Array(values.length);
	let completed = 0;
	values.forEach((v, i)=>{
		setTimeout(()=>{
			myFunc(taskName, i, v, timer).then(res=>{
				result[i]=res;
				completed++;
			});
		}, 0);
	});
	while (completed < values.length) await new Promise(res=>setTimeout(res, 1));
	return result;
}

/** 非同期タスク(ワーカースレッド) */
async function workerAll(taskName, values, timer) {
	return await Promise.all(
		values.map((v, i)=>new Promise(resolve=>
			new Worker(__filename,{workerData: [taskName, i, v, timer]})
			.once("message", resolve)
		))
	);
}

/** 非同期タスク(プロセス間通信) */
async function clusterAll(taskName, values, timer){
	return await Promise.all(
		values.map((v, i)=>new Promise(resolve=>{
			cluster.setupPrimary({args:[JSON.stringify([taskName, i, v, timer])]});
			cluster.fork().once("message", resolve);
		}))
	);
}

/** メイン関数 */
async function main(){
	const result = [["#Lang", "Task", "Index", "Value", "Result", "Start", "Sleeped", "Taraied", "Fibed", "SleepTime", "TaraiTime", "FibTime"]];
	const tasks = [
		["sync", syncAll],
		["async", asyncAll],
		["timeout", timeoutAll],
		["worker", workerAll],
		["cluster", clusterAll],
	]
	const values = [...Array(10)].map((_,i,l)=>l.length-i);
	for(const [taskName, task] of tasks){
		process.stdout.write(`!${taskName}: `);
		const timer = performance.now();
		result.push(...await task(taskName, values, timer));
		console.log(getTick(timer).toFixed(3));
	}
	console.log(result.map(row=>row.join("\t")).join("\n"));
	process.exit();
}

if (cluster.isPrimary && isMainThread) main();
else if (!isMainThread) myFuncSend(s=>parentPort.postMessage(s), ...workerData);
else myFuncSend(s=>process.send(s), ...JSON.parse(process.argv[2]));
