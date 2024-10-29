import time
import asyncio
from threading import Thread
from multiprocessing import Process, Manager
from concurrent import futures
from operator import setitem

"""たらい回し関数"""
tarai = lambda x,y,z: y if x<=y else tarai(tarai(x-1,y,z),tarai(y-1,z,x),tarai(z-1,x,y))
"""フィボナッチ関数"""
fib = lambda n: n if n<2 else fib(n-1)+fib(n-2)
"""タイマーの経過時間"""
getTick = lambda t: time.time()-t

async def myFunc(taskName, i, v, timer):
	"""テスト関数"""
	ticks = []
	spans = []
	ticks.append(getTick(timer))
	await asyncio.sleep(v*1e-3*100)
	ticks.append(getTick(timer))
	spans.append(ticks[-1]-ticks[-2])
	tarai(12, 6, 0)
	ticks.append(getTick(timer))
	spans.append(ticks[-1]-ticks[-2])
	fibResult = fib(30+v)
	ticks.append(getTick(timer))
	spans.append(ticks[-1]-ticks[-2])
	return ["Python", taskName, str(i), str(v), str(fibResult)]+[f"{t:.3f}" for t in ticks+spans]
def myFuncSync(*args):
	"""テスト関数(同期)"""
	return asyncio.run(myFunc(*args))
def myFuncSyncRefs(refs, i, args):
	"""テスト関数(配列参照代入)"""
	refs[i] = myFuncSync(*args)

async def syncAll(taskName, values, timer, _):
	"""同期タスク"""
	return [await myFunc(taskName, i, v, timer) for i, v in enumerate(values)]

async def asyncAll(taskName, values, timer, _):
	"""非同期タスク(シングルスレッド)"""
	return await asyncio.gather(*(myFunc(taskName, i, v, timer) for i, v in enumerate(values)))

def procAll(Task):
	"""非同期タスク(低水準スレッド/プロセス)"""
	async def __taskAll(taskName, values, timer, _):
		result = [None]*len(values)
		if Task is Process: result = Manager().list(result)
		threads = [
			Task(target=myFuncSyncRefs, args=(result, i, (taskName, i, v, timer,),))
			for i, v in enumerate(values)
		]
		for t in threads: t.start()
		for t in threads: t.join()
		return list(result)
	return __taskAll

async def futureAll(taskName, values, timer, executor):
	"""非同期タスク(高水準スレッド/プロセス)"""
	return [f.result() for f in [executor.submit(myFuncSync, taskName, i, v, timer) for i, v in enumerate(values)]]
	# return list(executor.map(myFuncSync, values))

async def main():
	"""メイン処理"""
	result = [["#Lang", "Task", "Index", "Value", "Result", "Start", "Sleeped", "Taraied", "Fibed", "SleepTime", "TaraiTime", "FibTime"]]
	tasks = (
		("sync", syncAll, None),
		("async", asyncAll, None),
		("thread", procAll(Thread), None),
		("process", procAll(Process), None),
		("futureThread", futureAll, futures.ThreadPoolExecutor),
		("futureProcess", futureAll, futures.ProcessPoolExecutor),
	)
	values = list(range(10,0,-1))
	for taskName, task, Executor in tasks:
		if Executor is None: Executor = futures.ThreadPoolExecutor
		with Executor(max_workers=len(values)) as executor:
			timer = time.time()
			result.extend(await task(taskName, values, timer, executor))
			print(f"!{taskName}:{getTick(timer):.3f}")
	print("\n".join("\t".join(row) for row in result))

if __name__=="__main__":
	asyncio.run(main())
