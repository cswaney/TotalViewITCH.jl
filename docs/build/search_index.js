var documenterSearchIndex = {"docs":
[{"location":"api/","page":"API","title":"API","text":"process","category":"page"},{"location":"api/#TotalViewITCH.process","page":"API","title":"TotalViewITCH.process","text":"process(file, version, date, nlevels, tickers, path)\n\nRead a binary data file and write message and order book data to file.\n\nArguments\n\nfile: location of file to read.\nversion: ITCH version number (4.1 or 5.0).\ndate: Date to associate with output.\nnlevels: number of order book levels to track.\ntickers: stock tickers to track.\ndir: location to write output.\n\n\n\n\n\n","category":"function"},{"location":"api/","page":"API","title":"API","text":"Recorder","category":"page"},{"location":"api/#TotalViewITCH.Recorder","page":"API","title":"TotalViewITCH.Recorder","text":"Recorder\n\nA data structure to manage writing data to CSV files.\n\nThe Recorder holds lines in a string. When the Recorder is full, the string is written to file and the string is emptied.\n\nNote that push! adds an end-of-line character to line. Thus, lines pushed to Recorders should not include ' '.\n\n\n\n\n\n","category":"type"},{"location":"api/","page":"API","title":"API","text":"build","category":"page"},{"location":"api/#TotalViewITCH.build","page":"API","title":"TotalViewITCH.build","text":"build(dir)\n\nScaffold a database at dir. The structure of the database is:\n\ndir\n |- books\n     |- aapl.csv\n     |- ...\n |- messages\n     |- aapl.csv\n     |- ...\n |- trades\n     |- aapl.csv\n     |- ...\n |- noii\n     |- aapl.csv\n     |- ...\n\n\n\n\n\n","category":"function"},{"location":"api/","page":"API","title":"API","text":"teardown","category":"page"},{"location":"api/#TotalViewITCH.teardown","page":"API","title":"TotalViewITCH.teardown","text":"teardown(dir; <kwargs>)\n\nDelete a database at dir.\n\n\n\n\n\n","category":"function"},{"location":"api/","page":"API","title":"API","text":"OrderMessage","category":"page"},{"location":"api/#TotalViewITCH.OrderMessage","page":"API","title":"TotalViewITCH.OrderMessage","text":"OrderMessage\n\nData structure representing order book updates.\n\n\n\n\n\n","category":"type"},{"location":"api/","page":"API","title":"API","text":"Book","category":"page"},{"location":"api/#TotalViewITCH.Book","page":"API","title":"TotalViewITCH.Book","text":"Book\n\nA limit order book.\n\nArguments\n\nname::String: the associated security name/ticker\nnlevels::Int: the number of levels reported\n\n\n\n\n\n","category":"type"},{"location":"api/","page":"API","title":"API","text":"Order","category":"page"},{"location":"api/#TotalViewITCH.Order","page":"API","title":"TotalViewITCH.Order","text":"Order\n\nA limit order.\n\n\n\n\n\n","category":"type"},{"location":"api/","page":"API","title":"API","text":"TradeMessage","category":"page"},{"location":"api/#TotalViewITCH.TradeMessage","page":"API","title":"TotalViewITCH.TradeMessage","text":"TradeMessage\n\nData structure representing trades.\n\n\n\n\n\n","category":"type"},{"location":"api/","page":"API","title":"API","text":"SystemMessage","category":"page"},{"location":"api/#TotalViewITCH.SystemMessage","page":"API","title":"TotalViewITCH.SystemMessage","text":"SystemMessage\n\nData structure representing system updates.\n\n\n\n\n\n","category":"type"},{"location":"api/","page":"API","title":"API","text":"NOIIMessage","category":"page"},{"location":"api/#TotalViewITCH.NOIIMessage","page":"API","title":"TotalViewITCH.NOIIMessage","text":"NOIIMessage\n\nData structure representing net order imbalance indicator messages and cross trade messages.\n\n\n\n\n\n","category":"type"},{"location":"#TotalViewITCH.jl","page":"Home","title":"TotalViewITCH.jl","text":"","category":"section"},{"location":"#Package-Features","page":"Home","title":"Package Features","text":"","category":"section"},{"location":"#Getting-Started","page":"Home","title":"Getting Started","text":"","category":"section"},{"location":"#Installation","page":"Home","title":"Installation","text":"","category":"section"},{"location":"#Basic-Usage","page":"Home","title":"Basic Usage","text":"","category":"section"},{"location":"#Distributed-Processing","page":"Home","title":"Distributed Processing","text":"","category":"section"},{"location":"#Contributing","page":"Home","title":"Contributing","text":"","category":"section"}]
}