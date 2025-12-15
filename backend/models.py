from flask_sqlalchemy import SQLAlchemy
from datetime import datetime
import uuid

# データベース操作用のオブジェクト
db = SQLAlchemy()

# 1. エリアマスター (例: 中央区)
class Area(db.Model):
    __tablename__ = 'areas'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    calendar_no = db.Column(db.String(10))
    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "calendar_no": self.calendar_no
        }

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
    color_code = db.Column(db.String(7)) # #FF0000
    icon_name = db.Column(db.String(50)) # fire
    def to_dict(self):
        return {
            "id": self.id,
            "name_ja": self.name_ja,
            "name_en": self.name_en,
            "color_code": self.color_code,
            "icon_name": self.icon_name
        }

# 4. 収集スケジュール
class Schedule(db.Model):
    __tablename__ = 'schedules'
    id = db.Column(db.Integer, primary_key=True)
    area_id = db.Column(db.Integer, db.ForeignKey('areas.id'), nullable=False)
    trash_type_id = db.Column(db.Integer, db.ForeignKey('trash_types.id'), nullable=False)
    date = db.Column(db.Date, nullable=False) 

    # リレーション設定
    trash_type = db.relationship('TrashType', backref='schedules')
    area = db.relationship('Area', backref='schedules')
    def to_dict(self):
        return {
            "id": self.id,
            "date": self.date.strftime('%Y-%m-%d'), # 日付を文字列に変換
            "area_id": self.area_id,
            "trash_type": self.trash_type.to_dict() # 関連するゴミ情報を埋め込む
        }

# 5. ゴミ分別辞書
class TrashDictionary(db.Model):
    __tablename__ = 'trash_dictionaries'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(255), nullable=False) 
    note = db.Column(db.Text) 
    fee = db.Column(db.String(100))
    trash_type_id = db.Column(db.Integer, db.ForeignKey('trash_types.id'), nullable=True)

    # リレーション
    trash_type = db.relationship('TrashType', backref='dictionaries')
    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "note": self.note,
            "fee": self.fee,
            # ゴミの種類があればその名前も返す
            "trash_type_name": self.trash_type.name_ja if self.trash_type else None
        }

# 6. ゴミ箱マップ (TrashBin)
class TrashBin(db.Model):
    __tablename__ = 'trash_bins'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(255), nullable=False) # 名称
    address = db.Column(db.String(255))              # 住所
    
    # ★重要: CSVにまだ緯度経度がないため、nullable=True (空でもOK) に変更
    latitude = db.Column(db.Float, nullable=True)
    longitude = db.Column(db.Float, nullable=True)
    
    bin_type = db.Column(db.String(255)) # 対象品目 (回収形態)
    note = db.Column(db.Text)            # 備考 + 利用可能時間など
    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "address": self.address,
            "latitude": self.latitude,
            "longitude": self.longitude,
            "bin_type": self.bin_type,
            "note": self.note
        }