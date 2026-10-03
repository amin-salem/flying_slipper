"""Permanent accounts: phone number, username + password, SMS codes.

Revision ID: 0002
Revises: 0001
Create Date: 2026-10-03
"""
import sqlalchemy as sa
from alembic import op

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)
    cols = {c["name"] for c in insp.get_columns("players")}
    # (a brand-new database already got these from 0001, so check first)
    with op.batch_alter_table("players") as b:
        if "phone" not in cols:
            b.add_column(sa.Column("phone", sa.String(15), nullable=True))
            b.create_unique_constraint("uq_players_phone", ["phone"])
        if "username" not in cols:
            b.add_column(sa.Column("username", sa.String(24), nullable=True))
            b.create_unique_constraint("uq_players_username", ["username"])
        if "password_hash" not in cols:
            b.add_column(sa.Column("password_hash", sa.String(200), nullable=True))
        if "secure_rewarded" not in cols:
            b.add_column(sa.Column("secure_rewarded", sa.Boolean(), nullable=False,
                                   server_default=sa.false()))
    if "otp_codes" not in insp.get_table_names():
        op.create_table(
            "otp_codes",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column("phone", sa.String(15), nullable=False),
            sa.Column("code_hash", sa.String(64), nullable=False),
            sa.Column("ip", sa.String(64), nullable=False, server_default=""),
            sa.Column("attempts", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("used", sa.Boolean(), nullable=False, server_default=sa.false()),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.Column("expires_at", sa.DateTime(), nullable=False),
        )
        op.create_index("ix_otp_phone_created", "otp_codes", ["phone", "created_at"])


def downgrade() -> None:
    op.drop_index("ix_otp_phone_created", table_name="otp_codes")
    op.drop_table("otp_codes")
    with op.batch_alter_table("players") as b:
        b.drop_constraint("uq_players_username", type_="unique")
        b.drop_constraint("uq_players_phone", type_="unique")
        for c in ("secure_rewarded", "password_hash", "username", "phone"):
            b.drop_column(c)
