from app import app
from models import db, Area, TrashType, TrashDictionary, Schedule

# データベースに初期データを入れる関数
def seed_data():
    with app.app_context():
        # 一旦中身を空にする（リセット）
        db.drop_all()
        db.create_all()

        print("データベースを作成しました...")

        # --- 1. エリアデータの作成 ---
        area1 = Area(name="中央区・豊平区(一部)", calendar_no="1")
        area2 = Area(name="北区・東区(一部)", calendar_no="2")
        db.session.add_all([area1, area2])
        db.session.commit() # 一度IDを確定させる

        # --- 2. ゴミ種別の作成 ---
        t_burn = TrashType(name_ja="燃えるゴミ", name_en="Burnable", color_code="#FF5733", icon_name="fire")
        t_plas = TrashType(name_ja="容器包装プラスチック", name_en="Plastic", color_code="#33FF57", icon_name="recycle")
        t_bin = TrashType(name_ja="びん・缶・ペットボトル", name_en="Bottles", color_code="#3357FF", icon_name="bottle")
        db.session.add_all([t_burn, t_plas, t_bin])
        db.session.commit()

        # --- 3. スケジュールの作成（中央区の例） ---
        # 燃えるゴミ: 月(0)・木(3)
        s1 = Schedule(area_id=area1.id, trash_type_id=t_burn.id, day_of_week=0)
        s2 = Schedule(area_id=area1.id, trash_type_id=t_burn.id, day_of_week=3)
        # プラ: 火(1)
        s3 = Schedule(area_id=area1.id, trash_type_id=t_plas.id, day_of_week=1)
        
        db.session.add_all([s1, s2, s3])

        # --- 4. 辞書データの作成 ---
        d1 = TrashDictionary(name="バナナの皮", name_kana="ばななのかわ", trash_type_id=t_burn.id, note="生ごみとして水気を切る")
        d2 = TrashDictionary(name="マヨネーズのボトル", name_kana="まよねーずのぼとる", trash_type_id=t_plas.id, note="中を洗ってから出す")
        
        db.session.add_all([d1, d2])

        db.session.commit()
        print("初期データの投入が完了しました！")

if __name__ == '__main__':
    seed_data()