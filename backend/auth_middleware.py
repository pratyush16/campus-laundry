"""
Admin Authentication Middleware
Session token authentication for protecting administrative endpoints.
"""

import os
import secrets
import time
from functools import wraps
from flask import request, jsonify

# In-memory session store: { token: { "admin_id": ..., "username": ..., "full_name": ..., "role": ..., "created_at": ... } }
_SESSIONS = {}
SESSION_EXPIRY_SECONDS = 24 * 3600  # 24 hours


def create_session(admin_data: dict) -> str:
    """Generate a secure session token and store admin session data."""
    token = secrets.token_hex(32)
    _SESSIONS[token] = {
        "admin_id": admin_data.get("admin_id"),
        "username": admin_data.get("username"),
        "full_name": admin_data.get("full_name"),
        "role": admin_data.get("role"),
        "created_at": time.time()
    }
    return token


def get_session(token: str):
    """Retrieve active session if not expired."""
    if not token or token not in _SESSIONS:
        return None
    session = _SESSIONS[token]
    if time.time() - session.get("created_at", 0) > SESSION_EXPIRY_SECONDS:
        _SESSIONS.pop(token, None)
        return None
    return session


def destroy_session(token: str) -> bool:
    """Invalidate an active session token."""
    if token in _SESSIONS:
        _SESSIONS.pop(token, None)
        return True
    return False


def get_token_from_request():
    """Extract token from Authorization header (Bearer), X-Admin-Token, or cookie."""
    auth_header = request.headers.get("Authorization", "")
    if auth_header.startswith("Bearer "):
        return auth_header[7:].strip()
    
    custom_header = request.headers.get("X-Admin-Token")
    if custom_header:
        return custom_header.strip()
        
    return request.cookies.get("admin_token")


def require_admin(f):
    """Decorator to enforce admin authentication on protected endpoints."""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        token = get_token_from_request()
        if not token:
            return jsonify({
                "success": False,
                "error": "Authentication required. Please log in as an administrator."
            }), 401

        session = get_session(token)
        if not session:
            return jsonify({
                "success": False,
                "error": "Session expired or invalid. Please log in again."
            }), 401

        request.admin = session
        return f(*args, **kwargs)
    return decorated_function
