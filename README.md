# reciko
### A bash script for recording radiko - Can be naming the program name in files
与えたキーワードを元に当日中の番組表から番組名と放送時間を取得し、
自動命名と自動終了を行ってくれるBashスクリプトです。(開始はcron又は手動)
##### Usage:
```
./reciko.sh [Station ID] [Program Keyword] [(none)|dry|dry-wh]
```
`Station ID` :   
radiko内部でそれぞれに割り当てられてるIDを指定  

`Program Keyword` :   
録画したい番組のフルタイトル、又は一部を入力(当日の番組表を参照)  
複数一致する条件・番組がある場合はエラーを吐きます  

`[(none)|dry|dry-run]` :  
空白で録画、`dry`で録画せずに該当する番組情報のみ吐き出し、`dry-wh`で同時にDiscord Webhookのテストポスト

#### `webhook`ファイルについて
内部にDiscord Webhookアドレスを記述しておくと録画開始時、終了時・失敗時に通知します。
