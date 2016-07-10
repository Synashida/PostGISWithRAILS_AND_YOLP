class TopController < ApplicationController
  def index
  end

  def get_cities
    # 引数の矩形情報をgeometryのpolygon形式に変換
    mapRegion = "#{params[:ne_lng]} #{params[:ne_lat]}, #{params[:nw_lng]} #{params[:nw_lat]}, #{params[:sw_lng]} #{params[:sw_lat]}, #{params[:se_lng]} #{params[:se_lat]}, #{params[:ne_lng]} #{params[:ne_lat]}"
    # polygonをgeometryに変換して、polygonに内包または接する矩形のみを取得
    regions = City.where("ST_Intersects(ST_GeomFromText('POLYGON((#{mapRegion}))', 4326), polygon)")
    # 取得したgeometryをYOLPのpolygon生成javascriptに変換したものをjsonとして描画
    render :json => multiPolygonToPolygonJson(regions)
  end

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
end
