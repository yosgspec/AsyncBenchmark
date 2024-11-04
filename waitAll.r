library(parallel)

#' @title たらい回し関数
tarai<-function(x,y,z) ifelse(x<=y, y, tarai(tarai(x-1,y,z),tarai(y-1,z,x),tarai(z-1,x,y)))
#' @title フィボナッチ関数
fib<-function(n) ifelse(n<2, n, fib(n-1)+fib(n-2))
#' @title タイマーの経過時間
getTick<-function(t) (Sys.time()-t)

#' @title テスト関数
myFunc<-function(taskName, i, v, timer){
	ticks<-numeric(0)
	spans<-numeric(0)
	ticks<-c(ticks, getTick(timer))
	Sys.sleep(v*100*1e-3)
	ticks<-c(ticks, getTick(timer))
	spans<-c(spans, ticks[length(ticks)]-ticks[length(ticks)-1])
	tarai(12, 6, 0)
	ticks<-c(ticks, getTick(timer))
	spans<-c(spans, ticks[length(ticks)]-ticks[length(ticks)-1])
	fibResult<-0#fib(30+v)
	ticks<-c(ticks, getTick(timer))
	spans<-c(spans, ticks[length(ticks)]-ticks[length(ticks)-1])
	c("R", taskName, as.character(c(i, v , fibResult)), sprintf("%.3f", c(ticks, spans)))
}

#' @title 同期処理
syncAll<-function(taskName, values, timer){
	lapply(seq_along(values), function(i) myFunc(taskName, i, values[i], timer))
}

#' @title 非同期処理(パラレル(プロセス))
parallelAll<-function(taskName, values, timer) {
	cluster<-makeCluster(length(values))
	clusterExport(cluster, varlist = c("myFunc", "getTick", "tarai", "fib"))
	result<-parLapply(cluster, seq_along(values), function(i) myFunc(taskName, i, values[i], timer))
	stopCluster(cluster)
	result
}

#' @title メイン処理
main<-function(){
	result<-list(c("#Lang", "Task", "Index", "Value", "Result", "Start", "Sleeped", "Taraied", "Fibed", "SleepTime", "TaraiTime", "FibTime"))
	tasks<-list(
		list(Name="sync", Fn=syncAll),
		list(Name="parallel", Fn=parallelAll)
	)
	values<-10:1
	for(task in tasks){
		cat("!", task$Name, ": ", sep="")
		timer<-Sys.time()
		result<-c(result, task$Fn(task$Name, values, timer))
		cat(sprintf("%.3f\n", getTick(timer)))
	}
	cat(paste(sapply(result, function(row) paste(row, collapse="\t")), collapse="\n"), "\n")
}

main()
