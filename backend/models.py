from flask_sqlalchemy import SQLAlchemy
from datetime import datetime
import uuid

# データベース操作用のオブジェクト
db = SQLAlchemy()

# 1. エリアマスター (例: 中央区)
class Area(db.Model):
    __tablename__ = 'areas'
    id = db.Column(db.Integer, primary_key=True)
    
    # 7ヶ国語対応
    name_ja = db.Column(db.String(100), nullable=False)
    name_en = db.Column(db.String(100))
    name_zh_cn = db.Column(db.String(100))
    name_ko = db.Column(db.String(100))
    name_vi = db.Column(db.String(100))
    name_ru = db.Column(db.String(100))
    name_id = db.Column(db.String(100))

    calendar_no = db.Column(db.String(10))
    ward_kanji = db.Column(db.String(50))
    area_number = db.Column(db.String(10))

    schedules = db.relationship('Schedule', backref='area', lazy=True)

    def to_dict(self):
        # 管理画面用など（デフォルトは日本語）
        return {
            "id": self.id,
            "name": self.name_ja,
            "calendar_no": self.calendar_no
        }
    
    def get_localized_name(self, lang_code):
        target_name = getattr(self, f'name_{lang_code}', None)
        return target_name if target_name else self.name_ja

# 2. ユーザー管理 (UUID)
class User(db.Model):
    __tablename__ = 'users'
    id = db.Column(db.Integer, primary_key=True)
    uuid = db.Column(db.String(36), unique=True, nullable=False, default=lambda: str(uuid.uuid4()))
    area_id = db.Column(db.Integer, db.ForeignKey('areas.id'), nullable=True)
    language = db.Column(db.String(5), default='ja')
    created_at = db.Column(db.DateTime, default=datetime.now)

    def to_dict(self):
        return {
            "id": self.id,
            "uuid": self.uuid,
            "area_id": self.area_id,
            "language": self.language
        }

# 3. ゴミ種別マスター (例: 燃えるゴミ)
class TrashType(db.Model):
    __tablename__ = 'trash_types'
    id = db.Column(db.Integer, primary_key=True)
    
    name_ja = db.Column(db.String(50), nullable=False)
    name_en = db.Column(db.String(50))
    name_zh_cn = db.Column(db.String(50))
    name_ko = db.Column(db.String(50))
    name_vi = db.Column(db.String(50))
    name_ru = db.Column(db.String(50))
    name_id = db.Column(db.String(50))

    color_code = db.Column(db.String(7))
    icon_name = db.Column(db.String(50))

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name_ja,
            "color": self.color_code,
            "icon": self.icon_name
        }

    def get_localized_name(self, lang_code):
        target_name = getattr(self, f'name_{lang_code}', None)
        return target_name if target_name else self.name_ja

# 4. 収集スケジュール
class Schedule(db.Model):
    __tablename__ = 'schedules'
    id = db.Column(db.Integer, primary_key=True)
    area_id = db.Column(db.Integer, db.ForeignKey('areas.id'), nullable=False)
    trash_type_id = db.Column(db.Integer, db.ForeignKey('trash_types.id'), nullable=False)
    date = db.Column(db.Date, nullable=False) 

    trash_type = db.relationship('TrashType', backref='schedules')

    def to_dict(self):
        return {
            "id": self.id,
            "date": self.date.strftime('%Y-%m-%d'),
            "area_id": self.area_id,
            "trash_type": self.trash_type.to_dict()
        }

# 5. ゴミ分別辞書 (TrashDictionary)
class TrashDictionary(db.Model):
    __tablename__ = 'trash_dictionaries'
    id = db.Column(db.Integer, primary_key=True)
    
    name_ja = db.Column(db.String(255), nullable=False)
    name_kana = db.Column(db.String(255)) # ★自動ソート用に追加
    name_en = db.Column(db.String(255))
    name_zh_cn = db.Column(db.String(255))
    name_ko = db.Column(db.String(255))
    name_vi = db.Column(db.String(255))
    name_ru = db.Column(db.String(255))
    name_id = db.Column(db.String(255))

    note_ja = db.Column(db.Text)
    note_en = db.Column(db.Text)
    note_zh_cn = db.Column(db.Text)
    note_ko = db.Column(db.Text)
    note_vi = db.Column(db.Text)
    note_ru = db.Column(db.Text)
    note_id = db.Column(db.Text)

    fee = db.Column(db.String(100))
    trash_type_id = db.Column(db.Integer, db.ForeignKey('trash_types.id'), nullable=True)

    trash_type = db.relationship('TrashType', backref='dictionaries')

    # ★Flutter用：言語コードを受け取って、その国の言葉で返す魔法のメソッド
    def get_localized_data(self, lang_code):
        # 1. 名前と言語の取得
        target_name = getattr(self, f'name_{lang_code}', None)
        target_note = getattr(self, f'note_{lang_code}', None)

        # 2. ゴミ種別名も言語変換する
        type_name = "未分類"
        if self.trash_type:
            type_name = self.trash_type.get_localized_name(lang_code)

        return {
            "id": self.id,
            "name": target_name if target_name else self.name_ja, # なければ日本語
            "kana": self.name_kana, # Flutter側でソート順として利用可能
            "note": target_note if target_note else self.note_ja,
            "fee": self.fee,
            "trash_type_name": type_name,
            "trash_type_id": self.trash_type_id
        }

# 6. ゴミ箱マップ (TrashBin)
class TrashBin(db.Model):
    __tablename__ = 'trash_bins'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(255), nullable=False) # 名称
    address = db.Column(db.String(255))              # 住所
    
    # ★重要: CSVにまだ緯度経度がないため、nullable=True (空でもOK) に変更
    latitude = db.Column(db.Float, nullable=True)    # 緯度
    longitude = db.Column(db.Float, nullable=True)   # 経度
    
    bin_type = db.Column(db.String(255))             # 種類（ペットボトル、空き缶など）
    note = db.Column(db.Text)                        # 備考

    def to_dict(self):
        # 全ての項目を返します
        return {
            "id": self.id,
            "name": self.name,
            "address": self.address,
            "latitude": self.latitude,
            "longitude": self.longitude,
            "bin_type": self.bin_type,
            "note": self.note
        }