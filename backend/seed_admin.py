"""
Seed Admin Users Utility
Creates initial administrator accounts with bcrypt password hashes.
Run: python seed_admin.py
"""

import os
import sys
from pathlib import Path
import bcrypt

# Ensure backend directory is in Python path
sys.path.append(str(Path(__file__).resolve().parent))
from database import execute_query, get_connection

DEFAULT_ADMINS = [
    {
        "username": "admin",
        "password": "admin123",
        "full_name": "System Administrator",
        "role": "superadmin"
    },
    {
        "username": "warden_b",
        "password": "warden123",
        "full_name": "Hostel Warden",
        "role": "warden"
    },
    {
        "username": "vendor_sparkle",
        "password": "vendor123",
        "full_name": "Sparkle Wash Admin",
        "role": "vendor"
    }
]

def seed_admins():
    print("=" * 55)
    print("   CampusLaundry Admin Seeder")
    print("=" * 55)

    conn = get_connection()
    cursor = conn.cursor()

    for admin in DEFAULT_ADMINS:
        username = admin["username"]
        plain_pw = admin["password"]
        full_name = admin["full_name"]
        role = admin["role"]

        # Hash with bcrypt
        salt = bcrypt.gensalt(rounds=12)
        password_hash = bcrypt.hashpw(plain_pw.encode("utf-8"), salt).decode("utf-8")

        cursor.execute("""
            INSERT INTO admin_users (username, password_hash, full_name, role, is_active)
            VALUES (%s, %s, %s, %s, TRUE)
            ON DUPLICATE KEY UPDATE
                password_hash = VALUES(password_hash),
                full_name = VALUES(full_name),
                role = VALUES(role),
                is_active = TRUE;
        """, (username, password_hash, full_name, role))

        print(f" [OK] Seeded '{username}' (Password: '{plain_pw}', Role: '{role}')")

    conn.commit()
    cursor.close()
    conn.close()
    print("=" * 55)
    print(" All admin accounts ready!")

if __name__ == "__main__":
    seed_admins()
