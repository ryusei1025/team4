import csv
import time
import re
from geopy.geocoders import Nominatim
from geopy.exc import GeocoderTimedOut

def add_coordinates():
    geolocator = Nominatim(user_agent="sapporo_banana_app_student_project_v2")
    
    input_file = 'dataset/trash_bins.csv'
    output_file = 'dataset/trash_bins_geo.csv'
    
    print("--- 住所変換（強化版）を開始します ---")

    try:
        with open(input_file, encoding='utf-8-sig') as f_in, \
             open(output_file, 'w', encoding='utf-8-sig', newline='') as f_out:
            
            reader = csv.DictReader(f_in)
            fieldnames = reader.fieldnames + ['latitude', 'longitude']
            writer = csv.DictWriter(f_out, fieldnames=fieldnames)
            writer.writeheader()
            
            count = 0
            success_count = 0

            for row in reader:
                count += 1
                original_address = row.get('住所', '')
                
                # 1. 基本の住所作成 ("北海道" がなければつける)
                search_address = original_address
                if "札幌市" in search_address and "北海道" not in search_address:
                    search_address = "北海道" + search_address

                lat = None
                lon = None
                
                # --- 検索ロジック ---
                try:
                    # パターンA: そのまま検索
                    location = geolocator.geocode(search_address)
                    
                    # パターンB: 失敗したら、番地（数字の羅列）を削って再検索
                    # 例: "北1条西2丁目3-4" -> "北1条西2丁目"
                    if not location:
                        # 末尾の数字やハイフンを削除する正規表現
                        broad_address = re.sub(r'[\d\-]+$', '', search_address)
                        if broad_address != search_address:
                            # print(f"  再挑戦: {broad_address}") # デバッグ用
                            location = geolocator.geocode(broad_address)

                    if location:
                        lat = location.latitude
                        lon = location.longitude
                        success_count += 1
                        print(f"[{count}] 成功: {original_address}")
                    else:
                        print(f"[{count}] 失敗: {original_address}")
                
                except Exception as e:
                    print(f"[{count}] エラー: {original_address} -> {e}")

                row['latitude'] = lat
                row['longitude'] = lon
                writer.writerow(row)
                
                # サーバーへの負荷軽減のため待機
                time.sleep(1.1)

            print("------------------------------------------------")
            print(f"完了！ {count}件中、{success_count}件の座標を取得しました。")

    except FileNotFoundError:
        print(f"エラー: {input_file} が見つかりません。")

if __name__ == "__main__":
    add_coordinates()