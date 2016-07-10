# PostGISWithRAILS_AND_YOLP

サンプルプログラムの概要
東京・千葉・埼玉・神奈川の範囲内で、地図を移動すると、現在表示している区画に一致する市区町村の境界をポリゴンで表示するサンプルです。

サンプルプログラム動作のために必要な外部環境
PostgreSQL
PostGIS
YOLPのアカウント
Ruby on Rails

環境構築方法
PostgreSQLにPostGISのExtensionを追加する
（PostGISのパッケージインストールについてはGoogle先生にお問い合わせください）

```
PostgreSQLにPostGIS Extensionを追加する
-- PostGISの追加
-- Enable PostGIS (includes raster)
CREATE EXTENSION postgis;
-- Enable Topology
CREATE EXTENSION postgis_topology;
-- fuzzy matching needed for Tiger
CREATE EXTENSION fuzzystrmatch;
-- Enable US Tiger Geocoder
CREATE EXTENSION postgis_tiger_geocoder;
```

サンプルデータを追加する
cloneしたプロジェクトの直下にcities.sqlがありますので、

`psql -h ご自身のホスト -Uご自身の接続ユーザ名 -p < cities.sql`

にてcitiesテーブルをインポートしてください。

Railsの環境を構築
サンプルプログラムのdatabase.ymlをご自身のPostgreSQL環境に合わせて修正してください

```config/database.yml
default: &default
  adapter: postgis
  encoding: unicode
  # For details on connection pooling, see rails configuration guide
  # http://guides.rubyonrails.org/configuring.html#database-pooling
  pool: 5
  username: <ご自身のPostgreSQLユーザ名>
  password: <PostgreSQLのパスワード>
  host: localhost
  port: 5432
  schema_search_path: public
```

YOLPのキーをご自身のキーを割り当ててください。

```app/views/top/index.html.erb 
<script src="http://js.api.olp.yahooapis.jp/OpenLocalPlatform/V1/jsapi?appid={ご自身のYOLPキーをご利用ください}" type="text/javascript"  charset="UTF-8"></script>
```

以上で準備が完了です。railsのサーバを起動して動作確認ができます。

`rails s`

にてサーバを起動し、localhost:3000/ にて地図上にYOLPが表示され、市区町村の境界線に沿ったポリゴンが表示されることを確認できます。
マウスで地図をドラッグすると、ポリゴンが描画されてない地区が表示されます。
ドラッグを終了すると現在の表示区画に一致する市区町村境界が緑色のポリゴンで描画されます。

コードのポイント解説
Gemはactiverecord-postgis-adapterを利用しています。

```Gemfile
gem 'activerecord-postgis-adapter'
gem 'pg', '~> 0.15'
```

geometry列を使ったモデルの作成は以下のようになります。

`rails g model city pref:string city:string polygon:geometry`

今回かなり手を抜いちゃっていますが、citiesテーブルに格納したgeometryをYOLPのポリゴンに変更するメソッドとして
multiPolygonToPolygonJsonを定義しています。
以下が実装になります。

```app/controllers/top_controller.rb
  # ActiveRecordで取得したpolygonをYOLPのpolygon生成javascriptへ変換
  def multiPolygonToPolygonJson(regions)
    # 市区町村毎のjavascriptを格納する結果配列
    result = []
    # 行毎にpolygon javascriptを生成
    regions.each do |row|
      # multipolygonのgeomeryは((polygon),(polygon))の形式で格納されているため、単一のポリゴン情報毎に分解
      polygons = row.polygon.to_s.split("),")

      result_points = ""
      polygons.each_with_index do |b, idx|
        # 余分な情報を除去
        points = b.gsub(/MULTIPOLYGON|\(|\)/, '')
        # PostGISの座標情報は Longtude Latitudeの形式になっていて、YOLPはLatitude Longtudeなので、座標を入れ替えてjavascript生成
        points = points.gsub(/([0-9\\.]+) ([0-9\\.]+)/, 'new Y.LatLng(\2, \1),').gsub(/,,/, ',')

        result_points += "var latlng#{row.id}_#{idx} = [ #{points} ];"
        result_points += <<-EOS
        var polygon#{row.id}_#{idx} = new Y.Polygon(
          latlng#{row.id}_#{idx},
          {
            strokeStyle: new Y.Style("cc0000", 4, 0.7),
            fillStyle: new Y.Style("00ff00", null, 0.2)
          });
        polygon#{row.id}_#{idx}.setClickable(false);
        map.addFeature(polygon#{row.id}_#{idx});
        EOS
      end
      # 生成したpolygonのjavascriptを配列に格納
      result.push(result_points);

    end
    result
   end
```

ポイントはPostGISで格納した座標がLon / Latになっているので、YOLP形式に合わせるときにLat/Lonに変換すること。
くらいです。
環境構築は手間ですができてしまうと矩形探査が非常に楽になりますので、
地図でなにかしたいときはPostGISを使うことをお勧めします。

