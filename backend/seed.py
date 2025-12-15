import csv
from datetime import datetime
from app import app
# ★修正1: TrashBin を追加でインポート
from models import db, Area, TrashType, Schedule, TrashDictionary, TrashBin

def seed_data():
    with app.app_context():
        # 1. データベースリセット
        db.drop_all()
        db.create_all()
        print("データベースをリセットしました。")

        # ---------------------------------------------------------
        # 2. ゴミ種別マスター作成
        # ---------------------------------------------------------
        trash_types_data = {
            1: {"name": "燃やせるごみ", "color": "#FF5733", "icon": "fire"},
            2: {"name": "燃やせないごみ", "color": "#3333FF", "icon": "delete"},
            8: {"name": "びん・缶・ペット", "color": "#33AAFF", "icon": "bottle"},
            9: {"name": "容器包装プラスチック", "color": "#33FF57", "icon": "recycle"},
            10: {"name": "雑がみ", "color": "#885522", "icon": "description"},
            11: {"name": "枝・葉・草", "color": "#228822", "icon": "grass"},
            99: {"name": "大型ごみ", "color": "#555555", "icon": "weekend"},
        }

        type_name_map = {
            "燃やせるごみ": 1,
            "燃やせないごみ": 2,
            "びん・缶・ペット": 8,
            "容器包装プラスチック": 9,
            "雑がみ": 10,
            "枝・葉・草": 11,
            "大型ごみ": 99
        }

        for t_id, info in trash_types_data.items():
            t = TrashType(id=t_id, name_ja=info["name"], name_en="Trash", color_code=info["color"], icon_name=info["icon"])
            db.session.add(t)
        db.session.commit()
        print("ゴミ種別マスターを作成しました。")

        # ---------------------------------------------------------
        # 3. スケジュールCSVの読み込み
        # ---------------------------------------------------------
        try:
            with open('dataset/schedules.csv', encoding='utf-8') as f:
                reader = csv.reader(f)
                header = next(reader)
                area_names = header[3:] 
                
                area_map = {}
                for name in area_names:
                    area_n = name[:-1]
                    cal_n = name[-1]
                    new_area = Area(name=name, calendar_no=cal_n)
                    db.session.add(new_area)
                    db.session.commit()
                    area_map[name] = new_area.id
                
                print(f"{len(area_map)} 箇所のエリアを登録しました。")

                schedule_list = []
                for row in reader:
                    date_str = row[1]
                    try:
                        date_obj = datetime.strptime(date_str, '%Y-%m-%dT%H:%M:%S').date()
                    except ValueError:
                        continue

                    for i, trash_val in enumerate(row[3:]):
                        if trash_val and trash_val.isdigit():
                            trash_id = int(trash_val)
                            if trash_id in trash_types_data:
                                area_name = area_names[i]
                                area_id = area_map[area_name]
                                s = Schedule(area_id=area_id, trash_type_id=trash_id, date=date_obj)
                                schedule_list.append(s)
                
                db.session.add_all(schedule_list)
                db.session.commit()
                print(f"スケジュール登録完了: {len(schedule_list)}件")

        except FileNotFoundError:
            print("エラー: dataset/schedules.csv が見つかりません。")


        # ---------------------------------------------------------
        # 4. ゴミ分別辞書CSVの読み込み
        # ---------------------------------------------------------
        try:
            with open('dataset/trash_dictionary.csv', encoding='utf-8-sig') as f:
                reader = csv.DictReader(f)
                
                dictionary_list = []
                for row in reader:
                    name = row.get('品目')
                    category_name = row.get('分別区分')
                    fee = row.get('手数料')
                    note = row.get('備考')

                    if not name: continue
                    t_id = type_name_map.get(category_name)
                    
                    d = TrashDictionary(
                        name=name,
                        note=note,
                        fee=fee,
                        trash_type_id=t_id
                    )
                    dictionary_list.append(d)
                
                db.session.add_all(dictionary_list)
                db.session.commit()
                print(f"分別辞書登録完了: {len(dictionary_list)}件")

        except FileNotFoundError:
            print("エラー: dataset/trash_dictionary.csv が見つかりません。")

        # ---------------------------------------------------------
        # 5. ゴミ箱マップCSVの読み込み (座標対応版)
        # ---------------------------------------------------------
        try:
            # ★ここを修正: 新しいファイル名 'trash_bins_geo.csv' を指定
            file_path = 'dataset/trash_bins_geo.csv'
            
            # まだ変換ファイルがない場合のエラー回避（念のため）
            import os
            if not os.path.exists(file_path):
                print("座標付きファイルがないため、元のCSVを使います")
                file_path = 'dataset/trash_bins.csv'

            with open(file_path, encoding='utf-8-sig') as f:
                reader = csv.DictReader(f)
                
                bin_list = []
                for row in reader:
                    if not row.get('名称'): continue

                    # 備考欄の作成
                    time_info = f"{row.get('開始時間', '')}～{row.get('終了時間', '')}"
                    days = row.get('利用可能曜日', '')
                    memo = row.get('備考', '')
                    full_note = f"【時間】{time_info} ({days}) / {memo}"
                    
                    # ★ここを修正: CSVから緯度経度を取り出す
                    lat_str = row.get('latitude')
                    lon_str = row.get('longitude')
                    
                    # 空っぽのときは None、数字があるときは float(小数) に変換
                    lat = float(lat_str) if lat_str and lat_str.strip() else None
                    lon = float(lon_str) if lon_str and lon_str.strip() else None

                    new_bin = TrashBin(
                        name=row.get('名称'),
                        address=row.get('住所'),
                        bin_type=row.get('対象品目'),
                        note=full_note,
                        latitude=lat,  # ★取得した値を入れる
                        longitude=lon  # ★取得した値を入れる
                    )
                    bin_list.append(new_bin)

                db.session.add_all(bin_list)
                db.session.commit()
                print(f"ゴミ箱データ登録完了: {len(bin_list)}件 (座標ファイル使用)")

        except FileNotFoundError:
            print(f"エラー: {file_path} が見つかりません。datasetフォルダを確認してください。")
        except ValueError as e:
            print(f"データの変換エラー: {e}")

if __name__ == '__main__':
    seed_data()