#| たらい回し関数 |#
(defun tarai(x y z) (if(<= x y) y (tarai (tarai (1- x) y z) (tarai (1- y) z x) (tarai (1- z) x y))))
#| フィボナッチ関数 |#
(defun fib(n) (if(< n 2) n (+(fib (1- n)) (fib(- n 2)))))
#| タイマーの経過時間 |#
(defun getTick(t-) (/(*(-(get-internal-real-time) t-))(get-internal-real-time)))

#| テスト関数 |#
(defun myFunc(taskName i v timer)
	(let(
		(ticks '())
		(spans '())
		(fibResult)
	)
		(push (getTick timer) ticks)
		(sleep (* v 100 1e-3))
		(push (getTick timer) ticks)
		(setf spans (nconc spans `(,(-(first ticks)(second ticks)))))
		(tarai 12 6 0)
		(push (getTick timer) ticks)
		(setf spans (nconc spans `(,(-(first ticks)(second ticks)))))
		(setf fibResult (fib (+ 30 v)))
		(push (getTick timer) ticks)
		(setf spans (nconc spans `(,(-(first ticks)(second ticks)))))
		(nconc
			(list "CommonLisp" taskName (write-to-string i) (write-to-string v) (write-to-string fibResult))
			(mapcar (lambda(f)(format nil "~,3f" f)) (nconc(nreverse ticks)spans))
		)
	)
)

#| 同期タスク |#
(defun syncAll(taskName values timer)
	(loop for v in values for i from 0 collect (myFunc taskName i v timer))
)

#| 非同期タスク(マルチスレッド) |#
(defun threadAll(taskName values timer)
	(let* (
		(threads (loop for v in values for i from 0 collect
			(sb-thread:make-thread #'myFunc :arguments (list taskName i v timer))
		))
	)
		(loop for thread in threads collect (sb-thread:join-thread thread))
	)
)

#| メイン関数 |#
(defun main ()
	(let(
		(result '(("#Lang" "Task" "Index" "Value" "Result" "Start" "Sleeped" "Taraied" "Fibed" "SleepTime" "TaraiTime" "FibTime")))
		(tasks '(
			("sync" syncAll)
			("thread" threadAll)
		))
		(values (loop for i from 10 downto 1 collect i))
	)
		(dolist(task tasks)
			(let((taskName (first task)) (taskFunc (second task))
				(timer (get-internal-real-time)))
				(setf result (nconc result (funcall taskFunc taskName values timer)))
				(format t "!~A:~,3f~%" taskName (getTick timer))
			)
		)
		(format t "~{~A~%~}" (loop for r in result collect (format nil "~{~A~^	~}" r)))
	)
)
(main)
