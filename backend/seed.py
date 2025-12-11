import csv
from datetime import datetime
from app import app
from models import db, Area, TrashType, Schedule, TrashDictionary

def seed_data():
    with app.app_context():
        # 1. データベースをリセット
        db.drop_all()
        db.create_all()
        print("データベースをリセットしました。")

        # 2. ゴミ種別マスター (CSVのIDに合わせて作成 + 色を追加)
        # CSVのID: 1=燃やせる, 2=燃やせない, 8=びん缶, 9=プラ, 10=雑がみ, 11=枝葉
        trash_types_data = {
            1: {"name": "燃やせるごみ", "color": "#FF5733", "icon": "fire"},   # 赤
            2: {"name": "燃やせないごみ", "color": "#3333FF", "icon": "delete"}, # 青
            8: {"name": "びん・缶・ペット", "color": "#33AAFF", "icon": "bottle"}, # 水色
            9: {"name": "容器プラ", "color": "#33FF57", "icon": "recycle"}, # 緑
            10: {"name": "雑がみ", "color": "#885522", "icon": "description"}, # 茶
            11: {"name": "枝・葉・草", "color": "#228822", "icon": "grass"}, # 深緑
            # 収集なしなどはスキップ
        }

        # TrashTypeオブジェクトを作って保存
        trash_type_objs = {}
        for t_id, info in trash_types_data.items():
            t = TrashType(id=t_id, name_ja=info["name"], name_en="Trash", color_code=info["color"], icon_name=info["icon"])
            db.session.add(t)
            trash_type_objs[t_id] = t
        
        db.session.commit()
        print("ゴミ種別マスターを作成しました。")

        # 3. スケジュールCSVの読み込み
        try:
            with open('schedules.csv', encoding='utf-8') as f:
                reader = csv.reader(f)
                header = next(reader) # 1行目（ヘッダー）を取得
                
                # エリア名のリスト（3列目以降がエリア名：中央区1, 中央区2...）
                area_names = header[3:] 
                
                # エリアをDBに登録
                area_map = {} # {"中央区1": area_id, ...}
                for name in area_names:
                    # 名前を分解 (例: "中央区1" -> name="中央区", calendar_no="1")
                    # 正規表現などで分けるのが丁寧ですが、簡易的に後ろ1文字をNoとする
                    area_n = name[:-1] 
                    cal_n = name[-1]
                    
                    new_area = Area(name=name, calendar_no=cal_n)
                    db.session.add(new_area)
                    db.session.commit()
                    area_map[name] = new_area.id
                
                print(f"{len(area_map)} 箇所のエリアを登録しました。")

                # 日付ごとのデータ登録（ここから重い処理）
                schedule_list = []
                for row in reader:
                    # 日付を取得 (例: 2025-10-01T00:00:00 -> 2025-10-01)
                    date_str = row[1]
                    try:
                        date_obj = datetime.strptime(date_str, '%Y-%m-%dT%H:%M:%S').date()
                    except ValueError:
                        continue # 日付がおかしい行は飛ばす

                    # 各エリアのゴミ情報を登録
                    for i, trash_val in enumerate(row[3:]): # 3列目以降がゴミID
                        if trash_val and trash_val.isdigit(): # 空欄でなければ
                            trash_id = int(trash_val)
                            
                            # 知っているゴミIDなら登録
                            if trash_id in trash_types_data:
                                area_name = area_names[i]
                                area_id = area_map[area_name]
                                
                                s = Schedule(
                                    area_id=area_id,
                                    trash_type_id=trash_id,
                                    date=date_obj,
                                )
                                schedule_list.append(s)

                    # メモリ節約のため100行ごとにコミットしても良いが、今回は一括で
                
                db.session.add_all(schedule_list)
                db.session.commit()
                print(f"{len(schedule_list)} 件のスケジュールを登録しました！完了！")

        except FileNotFoundError:
            print("エラー: schedules.csv が見つかりません。backendフォルダに置いてください。")
        except Exception as e:
            print(f"エラーが発生しました: {e}")

if __name__ == '__main__':
    seed_data()