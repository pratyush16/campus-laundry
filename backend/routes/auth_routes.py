"""
Admin Authentication Routes
Handles login, logout, and session verification for campus hostel administrators.
Optimized for high-performance sub-second authentication.
"""

import time
import threading
import bcrypt
from flask import Blueprint, request, jsonify
from database import execute_procedure, execute_query
from auth_middleware import create_session, get_session, destroy_session, require_admin, get_token_from_request

auth_bp = Blueprint("auth", __name__, url_prefix="/api/auth")

# In-memory fast cache for admin credential records (5 min TTL) to avoid cold database round trips
_ADMIN_CACHE = {}
ADMIN_CACHE_TTL = 300


def _get_admin_from_db_or_cache(username: str):
    now = time.time()
    cached = _ADMIN_CACHE.get(username)
    if cached and (now - cached["timestamp"] < ADMIN_CACHE_TTL):
        return cached["data"]

    try:
        results = execute_procedure("sp_AuthenticateAdmin", (username,))
        record = results[0] if results else None
    except Exception:
        rows = execute_query(
            "SELECT admin_id, username, password_hash, full_name, role, is_active, last_login FROM admin_users WHERE username = %s AND is_active = TRUE",
            (username,)
        )
        record = rows[0] if rows else None

    if record:
        _ADMIN_CACHE[username] = {"data": record, "timestamp": now}
    return record


def _async_update_last_login(admin_id: int):
    """Non-blocking background thread update for last_login."""
    try:
        execute_query(
            "UPDATE admin_users SET last_login = NOW() WHERE admin_id = %s",
            (admin_id,),
            commit=True
        )
    except Exception:
        pass


@auth_bp.route("/login", methods=["POST"])
def admin_login():
    """Authenticate admin using bcrypt hashed password verification."""
    data = request.get_json() or {}
    username = str(data.get("username", "")).strip().lower()
    password = str(data.get("password", "")).strip()

    if not username or not password:
        return jsonify({
            "success": False,
            "error": "Username and password are required."
        }), 400

    # 1. Fetch admin record
    admin_record = _get_admin_from_db_or_cache(username)
    if not admin_record:
        return jsonify({
            "success": False,
            "error": "Invalid username or password."
        }), 401

    password_hash = admin_record.get("password_hash", "")

    # 2. Verify password with bcrypt
    try:
        password_bytes = password.encode("utf-8")
        hash_bytes = password_hash.encode("utf-8") if isinstance(password_hash, str) else password_hash
        valid = bcrypt.checkpw(password_bytes, hash_bytes)
    except Exception as e:
        return jsonify({
            "success": False,
            "error": f"Authentication error: {str(e)}"
        }), 500

    if not valid:
        return jsonify({
            "success": False,
            "error": "Invalid username or password."
        }), 401

    # 3. Asynchronous last_login update (non-blocking)
    admin_id = admin_record.get("admin_id")
    if admin_id:
        threading.Thread(target=_async_update_last_login, args=(admin_id,), daemon=True).start()

    # 4. Create in-memory session token
    token = create_session(admin_record)

    return jsonify({
        "success": True,
        "token": token,
        "admin": {
            "admin_id": admin_record.get("admin_id"),
            "username": admin_record.get("username"),
            "full_name": admin_record.get("full_name"),
            "role": admin_record.get("role")
        }
    })


@auth_bp.route("/logout", methods=["POST"])
def admin_logout():
    """End active admin session."""
    token = get_token_from_request()
    if token:
        destroy_session(token)
    return jsonify({
        "success": True,
        "message": "Successfully logged out."
    })


@auth_bp.route("/me", methods=["GET"])
@require_admin
def admin_me():
    """Verify active admin session and return profile info instantly from memory."""
    return jsonify({
        "success": True,
        "admin": request.admin
    })
