# booklog_rec　

ソーシャル本棚サービス [booklog][]の非公式推薦 bot。  
Twitter bot [booklog_rec][] のコードが長くなったのでリファクタリングを兼ねて公開。  
ここで公開するプログラムの主な機能は以下のとおり。

1. booklog と Twitter を連携しているユーザをフォロー。
2. ユーザの蔵書情報を取得。
3. 新刊情報 tweet 生成。
4. おすすめ tweet 生成。

なお、おすすめ計算のメインは C で書いているので割愛。  
(気が向いたら公開。)

[booklog_rec]: http://twitter.com/booklog_rec "Twitter: booklog_rec"
[booklog]: http://booklog.jp "booklog"

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

過去に取得した情報を myamazon.log に吐き出すことで amazon に再問い合わせすることを回避。  
（api 制限があるのでできるだけ問い合わせ回数を節約したい。）  
また、api 制限に引っかかった場合は数秒待って再取得する。  
待ち時間は失敗するごとに増加（上限1時間）する。  
bot に積むようなので気長に待ってね。  

#### history
過去に取得した商品情報を格納したハッシュを返す。

#### show
これまでに取得した商品情報を表示。

#### backup
これまでに取得した商品情報を myamazon.log に書きだす。  
backup しなかった取得情報は破棄される。

***

## mybitly.rb
### 概要
bitly api を利用して long_url を short_url へ変換。  
以下の情報を書いた bitly_id.txt が必要。

1. account
2. api key

### メソッド一覧
#### shorten(long_url)
url を受け取り、短縮 url を返す。  
myamazon と同様、取得に失敗すると数秒待って再取得する。  
例えば、以下のように asin からその商品の短縮 url が取得可能。  

    a = MyAmazon.new
    b = MyBitly.new
    short_url = b.shorten(a.ask(asin)['url'])

***

## mytwitter.rb
### 概要
twitter api を利用して色々する。（特殊な機能は増えていない。）  
以下の情報を書いた twitter_id.txt が必要。

1. twitter id
2. consumer key
3. consumer key (secret)
4. oauth token
5. oauth token (secret)

### メソッド一覧
#### search(query, num)
query で検索した結果、見つかった tweet を num 件返す。
ただし上限は 1000 件。

#### timeline(num)
自身の timeline から tweet を num 件取得。
ただし上限は 1000 件。

#### ids2names(ids)
user id 集合 ids を受け取り、対応する screen name 集合を返す。

#### followers
自身の follower の screen name を返す。

#### followings
自身の following の screen name を返す。

#### follow(user)
user (screen name) を follow する。

#### unfollow(user)
user (screen name) を unfollow する。

#### friend?(user)
自身と user (screen name) が相互フォローならば真、そうでなければ偽を返す。

#### post(str)
str を topost.txt に追加する。（実際に post はしない。）

#### post_from_list(num, min)
topost.txt から毎 min 分 num tweets を実際に post する。
post した tweet は posted.txt に記録され、再 post しない。

***

## MyBooklog.rb
### 概要
各種 api を利用して以下を行う。

- twitter と booklog を連携しているユーザを検索
- booklog から蔵書情報を取得
- 新刊情報の取得

### メソッド一覧
いつか書く。

***

## MyRecommender
### 概要
メインの推薦エンジンの出力をもとに、おすすめツイートを生成する。

### メソッド一覧
いつか書く。
