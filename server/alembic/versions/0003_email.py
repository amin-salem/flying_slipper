"""Email + password accounts.

Revision ID: 0003
Revises: 0002
Create Date: 2026-10-04
"""
import sqlalchemy as sa
from alembic import op

revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    cols = {c["name"] for c in sa.inspect(op.get_bind()).get_columns("players")}
    if "email" not in cols:
        with op.batch_alter_table("players") as b:
            b.add_column(sa.Column("email", sa.String(120), nullable=True))
            b.create_unique_constraint("uq_players_email", ["email"])


def downgrade() -> None:
    with op.batch_alter_table("players") as b:
        b.drop_constraint("uq_players_email", type_="unique")
        b.drop_column("email")
