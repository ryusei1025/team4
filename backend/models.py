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

# 2. ユーザー管理 (UUID)
class User(db.Model):
    __tablename__ = 'users'
    id = db.Column(db.Integer, primary_key=True)
    # UUIDを自動生成する設定
    uuid = db.Column(db.String(36), unique=True, nullable=False, default=lambda: str(uuid.uuid4()))
    area_id = db.Column(db.Integer, db.ForeignKey('areas.id'), nullable=True)
    language = db.Column(db.String(5), default='ja')
    created_at = db.Column(db.DateTime, default=datetime.now)

# 3. ゴミ種別マスター (例: 燃えるゴミ)
class TrashType(db.Model):
    __tablename__ = 'trash_types'
    id = db.Column(db.Integer, primary_key=True)
    name_ja = db.Column(db.String(50), nullable=False)
    name_en = db.Column(db.String(50))
    color_code = db.Column(db.String(7)) # #FF0000
    icon_name = db.Column(db.String(50)) # fire

# 4. 収集スケジュール
class Schedule(db.Model):
    __tablename__ = 'schedules'
    id = db.Column(db.Integer, primary_key=True)
    area_id = db.Column(db.Integer, db.ForeignKey('areas.id'), nullable=False)
    trash_type_id = db.Column(db.Integer, db.ForeignKey('trash_types.id'), nullable=False)
    day_of_week = db.Column(db.Integer, nullable=False) # 0=月曜
    week_order = db.Column(db.Integer, default=0) # 0=毎週

    # リレーション設定（スケジュールからゴミ情報をすぐ取れるようにする）
    trash_type = db.relationship('TrashType', backref='schedules')
    area = db.relationship('Area', backref='schedules')

# 5. ゴミ分別辞書
class TrashDictionary(db.Model):
    __tablename__ = 'trash_dictionary'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    name_kana = db.Column(db.String(100), nullable=False)
    trash_type_id = db.Column(db.Integer, db.ForeignKey('trash_types.id'), nullable=False)
    note = db.Column(db.Text)
    
    trash_type = db.relationship('TrashType')

# 6. ゴミ箱マップ
class TrashBin(db.Model):
    __tablename__ = 'trash_bins'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    latitude = db.Column(db.Float, nullable=False)
    longitude = db.Column(db.Float, nullable=False)
    bin_type = db.Column(db.String(50))