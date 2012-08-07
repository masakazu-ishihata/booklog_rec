# booklog_rec　

Twitter bot "booklog_rec" のコードが長くなったのでリファクタリングを兼ねて公開。

## bot 詳細
ソーシャル本棚サービス "booklog" [1] の非公式推薦 bot [2]。
booklog と Twitter を連携しているユーザをフォローし、各ユーザの蔵書情報
をもとにユーザ毎の推薦を実現。
メインの推薦エンジンは c で書いてあるので割愛。

[1] http://booklog.jp/
[2] http://twitter.com/booklog_rec

## プログラムたち

### myamazon.rb

Amazon API をもとに作った。
ask(asin) で以下の情報を取得。
- titile
- author
- date
- url
