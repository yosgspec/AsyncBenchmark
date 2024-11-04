import subprocess
import time

sammary_file = "sammary.txt"
data_file = "data.txt"
trials = 5

header = "#Lang	Trials	Task	Index	Value	Result	Start	Sleeped	Taraied	Fibed	SleepTime	TaraiTime	FibTime"

# 名前とコマンドのペアをリストで定義 (ラベルが先、コマンドが後)
commands = [
	["START", ""],[
		"C++", "g++",
		"g++ -std=c++20 -O2 -o waitAll_cpp waitAll.cpp",
		"waitAll_cpp",
	],[
		"D", "dmd",
		"dmd -O -release -of=waitAll_d.exe waitAll.d",
		"waitAll_d"
	],[
		"JavaScript", "node",
		"node waitAll.js"
	],[
		"C#", "dotnet script",
		"dotnet script waitAll.cs"
	],[
		"CommonLisp", "sbcl",
		"sbcl --script waitall.lisp"
	],[
		"Python", "pypy",
		"pypy waitAll.py"
	],[
		"Python", "python",
		"python waitAll.py"
	],[
		"HSP", "hsp",
		"waitall_hsp"
	],[
		"R","rscript",
		"rscript waitAll.r"
	]
]

try:
	sammary = []
	data = [header]

	# コマンドを実行して結果を記録
	for param in commands:
		lang = param.pop(0)
		engine = param.pop(0)
		for trial in range(trials):
			timer = time.time()
			result = ""
			for cmd in param:
				result = subprocess.run(cmd, capture_output=True, text=True).stdout
			rows = f"!total: {time.time()-timer:.3f}\n{result}\n".splitlines()
			for row in rows:
				if row.startswith("#"):
					continue
				elif row.startswith("!"):
					sammary.append(row.replace("!", f"{lang}/{engine}({trial})!"))
					print(sammary[-1])
				elif row.startswith(lang):
					data.append(row.replace(lang, f"{lang}/{engine}\t{trial}"))

finally:
	with open(sammary_file, "w") as f:
		f.write("\n".join(sammary))
	with open(data_file, "w") as f:
		f.write("\n".join(data))
