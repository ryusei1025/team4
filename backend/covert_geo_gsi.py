import csv
import time
import requests
import urllib.parse

# ---------------------------------------------------------
# 国土地理院APIを使って、日本の住所を高精度に緯度経度変換するスクリプト
# ---------------------------------------------------------

def get_lat_lon_gsi(address):
    """
    国土地理院の住所検索APIを利用して緯度経度を取得する
    """
    # URLエンコード
    url_address = urllib.parse.quote(address)
    url = f"https://msearch.gsi.go.jp/address-search/AddressSearch?q={url_address}"
    
    try:
        response = requests.get(url)
        response.raise_for_status()
        data = response.json()
        
        if len(data) > 0:
            # 最も一致度が高い先頭のデータを採用
            # 国土地理院の座標は [経度(lon), 緯度(lat)] の順に入っている
            coordinates = data[0]["geometry"]["coordinates"]
            return coordinates[1], coordinates[0] # lat, lon
            
    except Exception as e:
        print(f"APIエラー: {e}")
    
    return None, None

def main():
    input_file = 'dataset/trash_bins.csv'
    output_file = 'dataset/trash_bins_geo.csv'
    
    print("--- 住所変換（国土地理院API版）を開始します ---")
    print("※1000件で数分かかります...")

    try:
        # 読み込みと書き込み
        with open(input_file, encoding='utf-8-sig') as f_in, \
             open(output_file, 'w', encoding='utf-8-sig', newline='') as f_out:
            
            reader = csv.DictReader(f_in)
            # ヘッダーに latitude, longitude を追加
            fieldnames = reader.fieldnames + ['latitude', 'longitude']
            writer = csv.DictWriter(f_out, fieldnames=fieldnames)
            writer.writeheader()
            
            count = 0
            success_count = 0

            for row in reader:
                count += 1
                original_address = row.get('住所', '')
                
                # 検索用住所を作成（北海道をつける）
                search_address = original_address
                if "北海道" not in search_address:
                    search_address = "北海道" + search_address
                
                # APIで取得
                lat, lon = get_lat_lon_gsi(search_address)

                # もし失敗したら、少し住所を曖昧にして再トライ（例: "XX番地-YY" -> "XX番地"）
                if lat is None and "-" in search_address:
                    short_address = search_address.split("-")[0]
                    # print(f"  再挑戦: {short_address}")
                    lat, lon = get_lat_lon_gsi(short_address)

                if lat:
                    success_count += 1
                    # print(f"[{count}] 成功: {original_address}")
                else:
                    print(f"[{count}] 失敗: {original_address}")

                # 結果をセット
                row['latitude'] = lat
                row['longitude'] = lon
                writer.writerow(row)
                
                # サーバーに負荷をかけないよう少し待機
                time.sleep(0.5)
                
                if count % 50 == 0:
                    print(f"{count}件 処理完了...")

            print("------------------------------------------------")
            print(f"完了！ {count}件中、{success_count}件の座標を取得しました。")
            print(f"作成ファイル: {output_file}")

    except FileNotFoundError:
        print(f"エラー: {input_file} が見つかりません。")

if __name__ == "__main__":
    main()