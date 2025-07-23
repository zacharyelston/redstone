#!/usr/bin/env python3
"""
Release.com API Client
Following the "Built for Clarity" design philosophy
"""

import os
import requests
import json
import logging
from typing import Dict, List, Optional, Any

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ReleaseAPIClient:
    """Client for interacting with Release.com API"""
    
    def __init__(self, api_token: Optional[str] = None, base_url: str = "https://api.release.com"):
        """
        Initialize Release.com API client
        
        Args:
            api_token: Release.com API token (defaults to RELEASE_API_TOKEN env var)
            base_url: Base URL for Release.com API
        """
        self.api_token = api_token or os.getenv('RELEASE_API_TOKEN')
        self.base_url = base_url.rstrip('/')
        self.session = requests.Session()
        
        if not self.api_token:
            raise ValueError("Release.com API token is required")
        
        self.session.headers.update({
            'Authorization': f'Bearer {self.api_token}',
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        })
    
    def _make_request(self, method: str, endpoint: str, **kwargs) -> Dict[str, Any]:
        """Make HTTP request to Release.com API"""
        url = f"{self.base_url}/{endpoint.lstrip('/')}"
        
        try:
            response = self.session.request(method, url, **kwargs)
            response.raise_for_status()
            return response.json() if response.content else {}
        except requests.exceptions.RequestException as e:
            logger.error(f"API request failed: {e}")
            raise
    
    def get_applications(self) -> List[Dict[str, Any]]:
        """Get list of applications"""
        return self._make_request('GET', '/applications')
    
    def get_application(self, app_id: str) -> Dict[str, Any]:
        """Get application details"""
        return self._make_request('GET', f'/applications/{app_id}')
    
    def create_application(self, name: str, repository_url: str, **kwargs) -> Dict[str, Any]:
        """Create new application"""
        data = {
            'name': name,
            'repository_url': repository_url,
            **kwargs
        }
        return self._make_request('POST', '/applications', json=data)
    
    def get_environments(self, app_id: str) -> List[Dict[str, Any]]:
        """Get environments for an application"""
        return self._make_request('GET', f'/applications/{app_id}/environments')
    
    def create_environment(self, app_id: str, name: str, **kwargs) -> Dict[str, Any]:
        """Create new environment"""
        data = {
            'name': name,
            **kwargs
        }
        return self._make_request('POST', f'/applications/{app_id}/environments', json=data)
    
    def deploy(self, app_id: str, environment_id: str, **kwargs) -> Dict[str, Any]:
        """Trigger deployment"""
        data = kwargs
        return self._make_request('POST', f'/applications/{app_id}/environments/{environment_id}/deployments', json=data)
    
    def get_deployments(self, app_id: str, environment_id: str) -> List[Dict[str, Any]]:
        """Get deployment history"""
        return self._make_request('GET', f'/applications/{app_id}/environments/{environment_id}/deployments')
    
    def get_deployment_status(self, app_id: str, environment_id: str, deployment_id: str) -> Dict[str, Any]:
        """Get deployment status"""
        return self._make_request('GET', f'/applications/{app_id}/environments/{environment_id}/deployments/{deployment_id}')

def main():
    """CLI interface for Release.com API client"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Release.com API Client')
    parser.add_argument('--token', help='API token (or set RELEASE_API_TOKEN env var)')
    parser.add_argument('command', choices=['apps', 'envs', 'deploy', 'status'])
    parser.add_argument('--app-id', help='Application ID')
    parser.add_argument('--env-id', help='Environment ID')
    parser.add_argument('--deployment-id', help='Deployment ID')
    
    args = parser.parse_args()
    
    try:
        client = ReleaseAPIClient(api_token=args.token)
        
        if args.command == 'apps':
            apps = client.get_applications()
            print(json.dumps(apps, indent=2))
        
        elif args.command == 'envs':
            if not args.app_id:
                print("--app-id is required for envs command")
                return
            envs = client.get_environments(args.app_id)
            print(json.dumps(envs, indent=2))
        
        elif args.command == 'status':
            if not all([args.app_id, args.env_id, args.deployment_id]):
                print("--app-id, --env-id, and --deployment-id are required for status command")
                return
            status = client.get_deployment_status(args.app_id, args.env_id, args.deployment_id)
            print(json.dumps(status, indent=2))
        
    except Exception as e:
        logger.error(f"Command failed: {e}")
        return 1
    
    return 0

if __name__ == '__main__':
    exit(main())
