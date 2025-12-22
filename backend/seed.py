import csv
from datetime import datetime
import re
from app import app
from models import db, Area, TrashType, Schedule, TrashDictionary, TrashBin

def seed_data():
    with app.app_context():
        # 1. データベースを一旦リセット (作り直し)
        db.drop_all()
        db.create_all()
        print("データベースをリセットしました。")

        # ---------------------------------------------------------
        # 2. ゴミ種別マスター作成 (7ヶ国語対応版！)
        # ---------------------------------------------------------
        print("ゴミ種別マスターを登録中...")
        
        # 翻訳データセット
        trash_types_data = [
            {
                "id": 1, "color": "#FF5733", "icon": "fire",
                "name_ja": "燃やせるごみ", "name_en": "Burnable", "name_zh_cn": "可燃垃圾", 
                "name_ko": "타는 쓰레기", "name_vi": "Rác cháy được", "name_ru": "Сжигаемый мусор", "name_id": "Sampah dibakar"
            },
            {
                "id": 2, "color": "#3333FF", "icon": "delete",
                "name_ja": "燃やせないごみ", "name_en": "Non-burnable", "name_zh_cn": "不可燃垃圾", 
                "name_ko": "타지 않는 쓰레기", "name_vi": "Rác không cháy", "name_ru": "Несжигаемый", "name_id": "Tidak dibakar"
            },
            {
                "id": 8, "color": "#33AAFF", "icon": "bottle",
                "name_ja": "びん・缶・ペット", "name_en": "Bottles/Cans", "name_zh_cn": "瓶/罐/塑料瓶", 
                "name_ko": "병/캔/페트병", "name_vi": "Chai/Lon/PET", "name_ru": "Бутылки/Банки", "name_id": "Botol/Kaleng"
            },
            {
                "id": 9, "color": "#33FF57", "icon": "recycle",
                "name_ja": "容器包装プラスチック", "name_en": "Plastic Packaging", "name_zh_cn": "塑料容器包装", 
                "name_ko": "플라스틱 용기", "name_vi": "Nhựa bao bì", "name_ru": "Пластик", "name_id": "Plastik Kemasan"
            },
            {
                "id": 10, "color": "#885522", "icon": "description",
                "name_ja": "雑がみ", "name_en": "Mixed Paper", "name_zh_cn": "其他纸类", 
                "name_ko": "잡종이", "name_vi": "Giấy tạp", "name_ru": "Макулатура", "name_id": "Kertas Campuran"
            },
            {
                "id": 11, "color": "#228822", "icon": "grass",
                "name_ja": "枝・葉・草", "name_en": "Leaves/Grass", "name_zh_cn": "树枝/树叶/草", 
                "name_ko": "나뭇가지/잎/풀", "name_vi": "Cành/Lá/Cỏ", "name_ru": "Ветки/Трава", "name_id": "Ranting/Daun"
            },
            {
                "id": 99, "color": "#555555", "icon": "weekend",
                "name_ja": "大型ごみ", "name_en": "Oversized Garbage", "name_zh_cn": "大型垃圾", 
                "name_ko": "대형 쓰레기", "name_vi": "Rác cồng kềnh", "name_ru": "Крупногабарит", "name_id": "Sampah Besar"
            },
        ]

        for data in trash_types_data:
            tt = TrashType(
                id=data["id"],
                color_code=data["color"],
                icon_name=data["icon"],
                name_ja=data["name_ja"], name_en=data["name_en"],
                name_zh_cn=data["name_zh_cn"], name_ko=data["name_ko"],
                name_vi=data["name_vi"], name_ru=data["name_ru"],
                name_id=data["name_id"]
            )
            db.session.add(tt)
        db.session.commit()


        # ---------------------------------------------------------
        # 3. 地域エリア登録
        # ---------------------------------------------------------
        print("地域エリアデータを登録中...")

        # 札幌10区の翻訳辞書
        ward_translations = {
            "中央区": {"en": "Chuo Ward", "zh": "中央区", "ko": "주오구", "vi": "Quận Chuo", "ru": "Район Чуо", "id": "Distrik Chuo"},
            "北区":   {"en": "Kita Ward", "zh": "北区", "ko": "기타구", "vi": "Quận Kita", "ru": "Район Кита", "id": "Distrik Kita"},
            "東区":   {"en": "Higashi Ward", "zh": "东区", "ko": "히가시구", "vi": "Quận Higashi", "ru": "Район Хигаси", "id": "Distrik Higashi"},
            "白石区": {"en": "Shiroishi Ward", "zh": "白石区", "ko": "시로이시구", "vi": "Quận Shiroishi", "ru": "Район Сироиси", "id": "Distrik Shiroishi"},
            "厚別区": {"en": "Atsubetsu Ward", "zh": "厚别区", "ko": "아쓰베쓰구", "vi": "Quận Atsubetsu", "ru": "Район Ацубэцу", "id": "Distrik Atsubetsu"},
            "豊平区": {"en": "Toyohira Ward", "zh": "丰平区", "ko": "도요히라구", "vi": "Quận Toyohira", "ru": "Район Тоёхира", "id": "Distrik Toyohira"},
            "清田区": {"en": "Kiyota Ward", "zh": "清田区", "ko": "기요타구", "vi": "Quận Kiyota", "ru": "Район Киёта", "id": "Distrik Kiyota"},
            "南区":   {"en": "Minami Ward", "zh": "南区", "ko": "미나미구", "vi": "Quận Minami", "ru": "Район Минами", "id": "Distrik Minami"},
            "西区":   {"en": "Nishi Ward", "zh": "西区", "ko": "니시구", "vi": "Quận Nishi", "ru": "Район Ниси", "id": "Distrik Nishi"},
            "手稲区": {"en": "Teine Ward", "zh": "手稻区", "ko": "데이네구", "vi": "Quận Teine", "ru": "Район Тэйнэ", "id": "Distrik Teine"},
        }
        
        schedules_file = 'dataset/schedules.csv'
        area_mapping_by_name = {} # "中央区1" -> Areaオブジェクト を一時保存する辞書
        
        try:
            with open(schedules_file, encoding='utf-8-sig') as f:
                reader = csv.reader(f)
                header = next(reader) # ヘッダー行を取得 (_id,日付,曜,中央区1,中央区2...)
                
                # ヘッダーの4列目以降がエリア名
                area_names = header[3:]
                
                for name in area_names:
                    # 正規表現で "中央区" と "1" に分ける
                    match = re.match(r"(.+区)(\d+)", name)
                    if match:
                        ward_kanji = match.group(1) # 例: "中央区"
                        area_num = int(match.group(2)) # 例: 1
                    
                        # 翻訳を取得
                        trans = ward_translations.get(ward_kanji, {})
                    
                        # Areaオブジェクト作成 (models.pyの変更に対応)
                        new_area = Area(
                            name_ja=name,       # "中央区1"
                        
                            # 多言語カラム (区名翻訳 + 番号)
                            name_en=f"{trans.get('en', ward_kanji)} {area_num}",
                            name_zh_cn=f"{trans.get('zh', ward_kanji)} {area_num}",
                            name_ko=f"{trans.get('ko', ward_kanji)} {area_num}",
                            name_vi=f"{trans.get('vi', ward_kanji)} {area_num}",
                            name_ru=f"{trans.get('ru', ward_kanji)} {area_num}",
                            name_id=f"{trans.get('id', ward_kanji)} {area_num}",
                        
                            # 新しく追加したカラム
                            ward_kanji=ward_kanji,
                            area_number=area_num,
                        
                            calendar_no="" # 今は使わないなら空でOK
                        )
                    
                        db.session.add(new_area)
                        area_mapping_by_name[name] = new_area

                db.session.commit()
                print(f"✅ 地域エリア {len(area_mapping_by_name)} 件を登録しました.")


            # ---------------------------------------------------------
            # 3.5 スケジュール登録
            # ---------------------------------------------------------
            print("収集日スケジュールを登録中...")
            with open(schedules_file, encoding='utf-8-sig') as f:
                reader = csv.DictReader(f)
                schedule_list = []
                
                for row in reader:
                    # 日付変換 "2025-10-01T00:00:00" -> Pythonのdate型
                    date_str = row['日付'].split('T')[0]
                    collection_date = datetime.strptime(date_str, '%Y-%m-%d').date()
                    
                    # 全カラムをループして、エリア名（中央区1など）の列だけ処理
                    for col_name, val in row.items():
                        if col_name in ['_id', '日付', '曜']:
                            continue
                    
                        # 値が入っている（ゴミ種別IDがある）場合のみ登録
                        if val and val.strip():
                            # さっき作った辞書から Areaオブジェクトを取り出す
                            area_obj = area_mapping_by_name.get(col_name)
                        
                            if area_obj:
                                try:
                                    trash_type_id = int(val)
                                    if trash_type_id > 0: 
                                        new_sch = Schedule(
                                            date=collection_date,
                                            area_id=area_obj.id,
                                            trash_type_id=trash_type_id
                                        )
                                        schedule_list.append(new_sch)
                                
                                except ValueError:
                                    pass # 数値じゃないゴミデータは無視

                db.session.add_all(schedule_list)
                db.session.commit()
                print(f"✅ スケジュール {len(schedule_list)} 件を登録しました。")

        except FileNotFoundError:
            print(f"エラー: {schedules_file} が見つかりません。")


        # ---------------------------------------------------------
        # 4. ゴミ分別辞書 (多言語CSV読み込み)
        # ---------------------------------------------------------
        print("ゴミ分別辞書データを登録中...")
        # ★ファイル名を変更しました
        dictionary_file = 'dataset/trash_dictionary_multilingual.csv'

        try:
            # encoding='utf-8-sig' はExcel保存のCSVでも文字化けしない魔法の設定です
            with open(dictionary_file, encoding='utf-8-sig') as f:
                reader = csv.DictReader(f)
                dict_list = []
                
                for row in reader:
                    # ゴミ種別IDの判定ロジック
                    trash_type_str = row.get('trash_type_str', '')
                    tid = None
                    if '燃やせる' in trash_type_str: tid = 1
                    elif '燃やせない' in trash_type_str: tid = 2
                    elif 'プラ' in trash_type_str: tid = 9
                    elif 'びん' in trash_type_str or '缶' in trash_type_str: tid = 8
                    elif '雑がみ' in trash_type_str: tid = 10
                    elif '枝' in trash_type_str: tid = 11
                    elif '大型' in trash_type_str: tid = 99

                    # ★ここが変更点！CSVの列をそのままモデルに入れます
                    item = TrashDictionary(
                        name_ja=row.get('name_ja'),
                        name_en=row.get('name_en'),
                        name_zh_cn=row.get('name_zh_cn'),
                        name_ko=row.get('name_ko'),
                        name_vi=row.get('name_vi'),
                        name_ru=row.get('name_ru'),
                        name_id=row.get('name_id'),
                        
                        note_ja=row.get('note_ja'),
                        note_en=row.get('note_en'),
                        # 他の言語のnoteがあればここに追加
                        
                        fee=row.get('fee'),
                        trash_type_id=tid
                    )
                    dict_list.append(item)
                
                db.session.add_all(dict_list)
                db.session.commit()
                print(f"多言語辞書データ {len(dict_list)} 件を登録しました！")

        except FileNotFoundError:
            print(f"エラー: {dictionary_file} が見つかりません。")

        
        # ---------------------------------------------------------
        # 5. ゴミ箱マップ (CSV読み込み - 緯度経度対応版)
        # ---------------------------------------------------------
        print("ゴミ箱マップデータを登録中...")
        # 既に変換済みの geo付きCSV があればそれを読み込む設定
        bins_file = 'dataset/trash_bins_geo.csv' 
        
        try:
            with open(bins_file, encoding='utf-8-sig') as f:
                reader = csv.DictReader(f)
                bin_list = []
                for row in reader:
                    lat_str = row.get('latitude')
                    lon_str = row.get('longitude')
                    lat = float(lat_str) if lat_str else None
                    lon = float(lon_str) if lon_str else None

                    new_bin = TrashBin(
                        name=row.get('名称') or row.get('場所名'), # CSVヘッダーに合わせて調整
                        address=row.get('住所'),
                        bin_type=row.get('対象品目') or row.get('種類'),
                        note=row.get('備考'),
                        latitude=lat,
                        longitude=lon
                    )
                    bin_list.append(new_bin)
                
                db.session.add_all(bin_list)
                db.session.commit()
                print(f"ゴミ箱データ {len(bin_list)} 件を登録しました！")

        except FileNotFoundError:
            print(f"注意: {bins_file} が見つかりませんでした。(スキップします)")

if __name__ == '__main__':
    seed_data()