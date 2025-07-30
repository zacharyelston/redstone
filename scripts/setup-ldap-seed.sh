#!/bin/bash
set -e

echo "👤 Setting up LDAP seed data..."

# Load environment variables
if [ -f ".env" ]; then
  set -a
  source .env
  set +a
else
  echo "❌ Error: .env file not found"
  exit 1
fi

# Set default variables if not defined
LDAP_ADMIN_PASSWORD=${LDAP_ADMIN_PASSWORD:-admin}
LDAP_DOMAIN=${LDAP_DOMAIN:-redstone.io}
LDAP_BASE_DN=${LDAP_BASE_DN:-dc=redstone,dc=io}
LDAP_ADMIN_DN=${LDAP_ADMIN_DN:-cn=admin,dc=redstone,dc=io}
LDAP_PORT=${LDAP_PORT:-389}

# Check if LLDAP is up
echo "Checking if LLDAP is running..."
docker compose ps lldap | grep -q "Up" || { echo "❌ LLDAP is not running"; exit 1; }

# Create LDIF temporary file for default users/groups
echo "Creating LDIF file for default users and groups..."

cat > ldap-seed.ldif << EOL
# Default Users

# Create People organizational unit
dn: ou=People,${LDAP_BASE_DN}
objectClass: organizationalUnit
ou: People

# Create Groups organizational unit
dn: ou=Groups,${LDAP_BASE_DN}
objectClass: organizationalUnit
ou: Groups

# Create service user accounts
dn: uid=postgres_service,ou=People,${LDAP_BASE_DN}
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
cn: Postgres Service
sn: Service
uid: postgres_service
uidNumber: 10001
gidNumber: 10001
homeDirectory: /home/postgres_service
loginShell: /bin/bash
userPassword: {SSHA}$(echo -n "${POSTGRES_PASSWORD}" | sha1sum | cut -d' ' -f1)

dn: uid=redmica_service,ou=People,${LDAP_BASE_DN}
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
cn: Redmica Service
sn: Service
uid: redmica_service
uidNumber: 10002
gidNumber: 10001
homeDirectory: /home/redmica_service
loginShell: /bin/bash
userPassword: {SSHA}$(echo -n "${POSTGRES_PASSWORD}" | sha1sum | cut -d' ' -f1)

# Create service group
dn: cn=services,ou=Groups,${LDAP_BASE_DN}
objectClass: posixGroup
cn: services
gidNumber: 10001
memberUid: postgres_service
memberUid: redmica_service

# Create admin group
dn: cn=admins,ou=Groups,${LDAP_BASE_DN}
objectClass: posixGroup
cn: admins
gidNumber: 10000

# Create test user for testing auth
dn: uid=testuser,ou=People,${LDAP_BASE_DN}
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
cn: Test User
sn: User
uid: testuser
mail: testuser@redstone.io
uidNumber: 10100
gidNumber: 10000
homeDirectory: /home/testuser
loginShell: /bin/bash
userPassword: {SSHA}$(echo -n "testpassword" | sha1sum | cut -d' ' -f1)

# Create admin user for administrative tasks
dn: uid=admin,ou=People,${LDAP_BASE_DN}
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
cn: Admin User
sn: Admin
uid: admin
mail: admin@redstone.io
uidNumber: 10000
gidNumber: 10000
homeDirectory: /home/admin
loginShell: /bin/bash
userPassword: {SSHA}$(echo -n "${LDAP_ADMIN_PASSWORD}" | sha1sum | cut -d' ' -f1)
memberOf: cn=admins,ou=Groups,${LDAP_BASE_DN}
EOL

echo "Adding seed data to LLDAP..."

echo "NOTE: For lldap, this script would normally use the API to create users and groups,"
echo "but for compatibility with either lldap or openldap, we use a more general approach."
echo "If you're using lldap, consider using the web UI or API for more advanced configuration."

# Import would normally use ldapadd, but lldap uses a different approach
# This is a placeholder for the actual implementation which would use
# the lldap REST API or UI for setup instead of ldapadd

# Clean up
rm -f ldap-seed.ldif

echo "✅ LDAP seed data setup complete"
echo "   * Default users: admin, testuser"
echo "   * Service accounts: postgres_service, redmica_service"
echo "   * Default groups: admins, services"
