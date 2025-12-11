import csv
from app import app
from models import db, Area, TrashType, Schedule, TrashDictionary

def seed_data():
    with app.app_context():
        # 1. 一旦データをリセット（開発中なので便利）
        db.drop_all()
        db.create_all()
        print("データベースをリセットしました。")

        # 2. 基本のゴミ種別マスターを作成（ここは固定でOK）
        t_burn = TrashType(name_ja="燃えるゴミ", name_en="Burnable", color_code="#FF5733", icon_name="fire")
        t_plas = TrashType(name_ja="容器包装プラスチック", name_en="Plastic", color_code="#33FF57", icon_name="recycle")
        t_bin = TrashType(name_ja="びん・缶・ペットボトル", name_en="Bottles", color_code="#3357FF", icon_name="bottle")
        t_paper = TrashType(name_ja="雑がみ", name_en="Paper", color_code="#333333", icon_name="description")
        
        db.session.add_all([t_burn, t_plas, t_bin, t_paper])
        db.session.commit()
        print("ゴミ種別マスターを作成しました。")

        # 3. CSVからエリアとスケジュールを読み込む
        # 読み込み済みのエリアを管理する辞書
        area_cache = {} 

        try:
            with open('garbage_data.csv', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                
                for row in reader:
                    # --- エリアの登録 ---
                    area_name = row['area_name']
                    if area_name not in area_cache:
                        # まだ登録していないエリアなら作成
                        new_area = Area(name=area_name, calendar_no=row['calendar_no'])
                        db.session.add(new_area)
                        db.session.commit()
                        # IDを覚えておく（キャッシュ）
                        area_cache[area_name] = new_area.id
                    
                    area_id = area_cache[area_name]

                    # --- スケジュールの登録 ---
                    new_schedule = Schedule(
                        area_id=area_id,
                        trash_type_id=int(row['trash_type_id']),
                        day_of_week=int(row['day_of_week']),
                        week_order=0 # 毎週
                    )
                    db.session.add(new_schedule)
                
                db.session.commit()
                print("CSVからデータをインポートしました！")

        except FileNotFoundError:
            print("エラー: garbage_data.csv が見つかりません。")

if __name__ == '__main__':
    seed_data()