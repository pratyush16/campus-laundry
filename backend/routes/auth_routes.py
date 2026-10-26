"""
Admin Authentication Routes
Handles login, logout, and session verification for campus hostel administrators.
"""

import bcrypt
from flask import Blueprint, request, jsonify
from database import execute_procedure, execute_query
from auth_middleware import create_session, get_session, destroy_session, require_admin, get_token_from_request

auth_bp = Blueprint("auth", __name__, url_prefix="/api/auth")


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

    # 1. Query admin record via stored procedure sp_AuthenticateAdmin
    try:
        results = execute_procedure("sp_AuthenticateAdmin", (username,))
        admin_record = results[0] if results else None
    except Exception:
        # Fallback query if procedure unavailable
        rows = execute_query(
            "SELECT admin_id, username, password_hash, full_name, role, is_active, last_login FROM admin_users WHERE username = %s AND is_active = TRUE",
            (username,)
        )
        admin_record = rows[0] if rows else None

    if not admin_record:
        return jsonify({
            "success": False,
            "error": "Invalid username or password."
        }), 401

    # admin_record is a dict from RealDictCursor:
    # keys: admin_id, username, password_hash, full_name, role, is_active, last_login
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

    # 3. Update last_login timestamp
    try:
        execute_query(
            "UPDATE admin_users SET last_login = NOW() WHERE admin_id = %s",
            (admin_record.get("admin_id"),),
            commit=True
        )
    except Exception:
        pass

    # 4. Create session token
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
    """Verify active admin session and return profile info."""
    return jsonify({
        "success": True,
        "admin": request.admin
    })
