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

過去に取得した情報は log ファイルに吐き出すことで amazon に再問い合わせすることを回避。
（api 制限があるのでできるだけ問い合わせ回数を節約したい。）
また、api 制限に引っかかった場合は数秒待って再取得する。
待ち時間は失敗するごとに増加（上限1時間）する。
bot に積むようなので気長に待ってね。


### mybitly.rb

bitly api を利用して long_url を short_url へ変換。
shorten(long_url) で短縮 url を返す。
myamazon と同様、取得に失敗すると数秒待って再取得する。
