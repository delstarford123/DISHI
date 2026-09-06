from flask import Blueprint

v3_bp = Blueprint('v3', __name__, url_prefix='/v3')

# Import routes here to register them with the blueprint
from . import academic_routes
