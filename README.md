# booklog_rec　

Twitter bot "booklog_rec"[1] のコードが長くなったのでリファクタリングを兼ねて公開。
ソーシャル本棚サービス "booklog"[2] の非公式推薦 bot。
booklog と Twitter を連携しているユーザをフォローし、各ユーザの蔵書情報
をもとにユーザ毎の推薦を実現。
メインの推薦エンジンは c で書いてあるので割愛。

[1] http://twitter.com/booklog_rec
[2] http://booklog.jp



# プログラムたち

## myamazon.rb
### 概要
Amazon API を利用し、商品の asin から商品情報を取得。

以下の情報を書いた amazon_id.txt が必要。
1. associate tag
2. aws access key 
3. aws secret key

### メソッド一覧
#### ask(asin)
商品 asin を受け取り、以下の情報を含むハッシュを返す。
1. titile
2. author
3. date
4. url

過去に取得した情報は log ファイルに吐き出すことで amazon に再問い合わせすることを回避。
（api 制限があるのでできるだけ問い合わせ回数を節約したい。）
また、api 制限に引っかかった場合は数秒待って再取得する。
待ち時間は失敗するごとに増加（上限1時間）する。
bot に積むようなので気長に待ってね。

## mybitly.rb
### 概要
bitly api を利用して long_url を short_url へ変換。

以下の情報を書いた bitly_id.txt が必要。
- account
- api key

### メソッド一覧
#### shorten(long_url)
url を受け取り、短縮 url を返す。
myamazon と同様、取得に失敗すると数秒待って再取得する。
例えば、以下のように asin からその商品の短縮 url が取得可能。

a = MyAmazon.new
b = MyBitly.new
p b.shorten(a.ask(asin)['url'])


## mytwitter.rb
### 概要
twitter api を利用して色々する。
（特殊な機能は増えていない。）

以下の情報を書いた twitter_id.txt が必要。
- twitter id
- consumer key
- consumer key (secret)
- oauth token
- oauth token (secret)

### メソッド一覧
#### 