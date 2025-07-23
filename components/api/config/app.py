#!/usr/bin/env python3
"""
Redstone API Service
Following the "Built for Clarity" design philosophy
"""

from flask import Flask, jsonify, request
import os
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Configuration
app.config['DEBUG'] = os.getenv('DEBUG', 'false').lower() == 'true'
app.config['SECRET_KEY'] = os.getenv('API_SECRET_KEY', 'dev-secret-key')

@app.route('/health')
def health_check():
    """Health check endpoint for Release.com"""
    return jsonify({
        'status': 'healthy',
        'service': 'redstone-api',
        'version': '1.0.0'
    })

@app.route('/api/status')
def api_status():
    """API status endpoint"""
    return jsonify({
        'api': 'running',
        'database': 'connected',  # TODO: Add actual DB health check
        'timestamp': '2025-01-01T00:00:00Z'  # TODO: Add actual timestamp
    })

@app.route('/api/info')
def api_info():
    """API information endpoint"""
    return jsonify({
        'name': 'Redstone API',
        'description': 'API service for Redstone project management platform',
        'version': '1.0.0',
        'environment': os.getenv('ENVIRONMENT', 'development')
    })

if __name__ == '__main__':
    port = int(os.getenv('PORT', 8080))
    host = os.getenv('HOST', '0.0.0.0')
    
    logger.info(f"Starting Redstone API service on {host}:{port}")
    app.run(host=host, port=port, debug=app.config['DEBUG'])
