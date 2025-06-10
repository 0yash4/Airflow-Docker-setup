# Apache Airflow Docker Setup Guide

A step-by-step guide to set up Apache Airflow using Docker Compose on any Linux cloud instance with minimal resource requirements.

This setup is optimized for:
- **Low resource consumption** (ideal for small cloud instances)
- **Quick deployment** with Docker Compose
- **Local development** and side projects
- **Single-node setup** with PostgreSQL backend

## 📋 Prerequisites

- Linux-based cloud instance (Ubuntu 20.04+ recommended)
- Minimum 2GB RAM, 1 CPU core
- 10GB+ available disk space
- Root or sudo access

## 🛠️ Step 1: Initial Server Setup

### Update your system
```bash
sudo apt update && sudo apt upgrade -y
```

### Install required packages
```bash
sudo apt install -y curl wget git vim
```

## 📁 Step 2: Clone and Setup Project

### Clone the repository
```bash
git clone https://github.com/0yash4/Airflow-Docker-setup.git
cd Airflow-Docker-setup
```

### Make scripts executable
```bash
chmod +x docker_python_installer.sh
chmod +x docker_user_fix.sh
```

### Execute the Scripts
```bash
sudo ./docker_python_installer.sh
sudo ./docker_user_fix.sh
```

### Important: Log Out and Back In
After running the installation script, you **must** log out and log back in for Docker commands to work without `sudo`:

```bash
# Option 1: Log out and back in (recommended)
exit
```
```bash
# Option 2: Apply group changes in current session
newgrp docker
```

### Verify Installation
```bash
# Check Docker version
docker --version

# Check Docker Compose
docker compose version

# Check Python version
python3 --version

# Test Docker (after logging out and back in)
docker run hello-world
```

### Create required directories and set permissions
```bash
# Create all necessary Airflow directories in current folder
mkdir -p dags logs plugins config

# Set proper ownership and permissions for Airflow directories
sudo chown -R $(id -u):$(id -g) dags logs plugins config
chmod -R 755 dags logs plugins config
```

**Directory Structure Explanation:**
- `dags/` - Contains your Airflow DAG files (Python workflows)
- `logs/` - Stores Airflow task execution logs
- `plugins/` - Custom Airflow plugins and operators
- `config/` - Additional Airflow configuration files

### Set proper permissions
```bash
# Create .env file for user configuration
echo "AIRFLOW_UID=$(id -u)" > .env
echo "_AIRFLOW_WWW_USER_CREATE=true" >> .env
echo "_AIRFLOW_WWW_USER_USERNAME=admin" >> .env
echo "_AIRFLOW_WWW_USER_PASSWORD=admin123" >> .env
echo "_AIRFLOW_WWW_USER_EMAIL=Admin" >> .env

# Ensure directories have correct permissions (already done above, but double-check)
sudo chown -R $(id -u):$(id -g) dags logs plugins config
chmod -R 755 dags logs plugins config
```

## 🏗️ Step 4: Create Dockerfile

Create a `DOCKERFILE` in your project root:

```bash
cat > DOCKERFILE << 'EOF'
FROM apache/airflow:latest

USER root

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    python3-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

USER airflow

# Install additional Python packages
COPY requirements.txt /requirements.txt
RUN pip install --no-cache-dir -r /requirements.txt
EOF
```

## 🚀 Step 5: Launch Airflow

### Initialize the database
```bash
# Using Docker Compose plugin (recommended)
docker compose up airflow-init
```

### Start all services
```bash
# Using Docker Compose plugin (recommended)
docker compose up -d
```

### Check service status
```bash
# Using Docker Compose plugin
docker compose ps
```

You should see all services running:
- `postgres` (database)
- `airflow-webserver` (web UI)
- `airflow-scheduler` (task scheduler)

## 🌐 Step 7: Access Airflow Web UI

### Open firewall port (if needed)
```bash
# For Ubuntu/Debian with ufw
sudo ufw allow 8080

# For CentOS/RHEL with firewalld
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload
```
### Expose Port 8080 in your management console
![image](https://github.com/user-attachments/assets/b5a938b5-e643-4e14-bba2-e4bde949b0bd)

### Access the web interface
Open your browser and navigate to:
**Note: Airflow Webserver can only be accessed through `Http://` and will not work if you use `Https://`** 
```
http://your-server-ip:8080
```

**Default credentials:**
- Username: `admin` (or what you set in .env)
- Password: `admin123` (or what you set in .env)

## 📝 Step 8: Create Your First DAG

Create a sample DAG in the `dags` folder:

```bash
cat > dags/hello_world_dag.py << 'EOF'
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator

def print_hello():
    return 'Hello World from Airflow!'

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

dag = DAG(
    'hello_world',
    default_args=default_args,
    description='A simple Hello World DAG',
    schedule_interval='@daily',
    catchup=False,
)

# Task 1: Bash command
hello_bash = BashOperator(
    task_id='hello_bash',
    bash_command='echo "Hello World from Bash!"',
    dag=dag,
)

# Task 2: Python function
hello_python = PythonOperator(
    task_id='hello_python',
    python_callable=print_hello,
    dag=dag,
)

# Set task dependencies
hello_bash >> hello_python
EOF
```

The DAG will automatically appear in the Airflow UI within a few minutes.

## 🔧 Management Commands

### Create/View Users
   **Add New User:**
   ```bash
   docker compose run --rm airflow-cli airflow users create \
   --username <name> \
   --firstname <firstname> \
   --lastname <lastname> \
   --role <Admin/User/Viewer/'Other'> \
   --email <email@example.com> \
   --password <Strong_Password>
   ```
   **See User List:**
   ```bash
   docker compose run --rm airflow-cli airflow users list
   ```

### View logs
```bash
# All services (Docker Compose plugin)
docker compose logs

# All services (standalone docker-compose)
docker-compose logs

# Specific service
docker compose logs airflow-webserver
docker compose logs airflow-scheduler
```

### Restart services
```bash
# Restart all (Docker Compose plugin)
docker compose restart

# Restart all (standalone docker-compose)
docker-compose restart

# Restart specific service
docker compose restart airflow-webserver
```

### Stop services
```bash
# Docker Compose plugin
docker compose down

# Standalone docker-compose
docker-compose down
```

### Stop and remove all data
```bash
# Docker Compose plugin
docker compose down -v

# Standalone docker-compose  
docker-compose down -v
```

### 🧹 Full Docker Compose Cleanup Commands
```bash
# 1. Stop all running containers and remove containers, networks, volumes, and images created by docker-compose
docker compose down --volumes --remove-orphans

# 2. Remove all build cache (optional, but recommended for clean build)
docker builder prune --all --force

# 3. Optionally, remove all stopped containers and dangling images (extra clean)
docker system prune --volumes --all --force
```

### Access Airflow CLI
```bash
# Run airflow commands (Docker Compose plugin)
docker compose exec airflow-webserver airflow --help

# Run airflow commands (standalone docker-compose)
docker-compose exec airflow-webserver airflow --help

# List DAGs
docker compose exec airflow-webserver airflow dags list

# Test a task
docker compose exec airflow-webserver airflow tasks test hello_world hello_bash 2024-01-01
```

## 🔍 Troubleshooting

### Common Issues

1. **Permission denied errors:**
   ```bash
   sudo chown -R $(id -u):$(id -g) dags logs plugins config
   ```

2. **Port 8080 already in use:**
   ```bash
   # Check what's using the port
   sudo netstat -tulpn | grep 8080
   # Kill the process or change port in docker-compose.yml
   ```

3. **Memory issues:**
   ```bash
   # Check available memory
   free -h
   # Consider upgrading your instance or reducing worker processes
   ```

4. **Database connection issues:**
   ```bash
   # Check PostgreSQL container
   docker-compose logs postgres
   # Restart database
   docker-compose restart postgres
   ```

### Health Checks

```bash
# Check container health
docker-compose ps

# Check Airflow health endpoint
curl http://localhost:8080/health

# Check scheduler health
curl http://localhost:8974/health
```

## 📊 Resource Optimization

This setup is optimized for low resources with:
- `MAX_ACTIVE_RUNS_PER_DAG: 1` - Only one DAG run at a time
- `MAX_ACTIVE_TASKS_PER_DAG: 2` - Maximum 2 concurrent tasks
- `WEBSERVER_WORKERS: 1` - Single web server worker
- Memory limits on containers
- CPU limits on containers

## 🔐 Security Considerations

For production use, consider:

1. **Change default passwords:**
   ```bash
   # Update .env file
   echo "_AIRFLOW_WWW_USER_PASSWORD=your-strong-password" >> .env
   ```

2. **Use environment variables for secrets:**
   ```bash
   # Add to .env
   echo "AIRFLOW__CORE__FERNET_KEY=$(python -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())')" >> .env
   ```

3. **Setup SSL/TLS** for web interface
4. **Configure proper firewall rules**
5. **Regular backups** of PostgreSQL data

## 📚 Next Steps

1. Explore [Airflow documentation](https://airflow.apache.org/docs/)
2. Learn about [Airflow operators](https://airflow.apache.org/docs/apache-airflow/stable/concepts/operators.html)
3. Set up [connections and variables](https://airflow.apache.org/docs/apache-airflow/stable/concepts/connections.html)
4. Configure [email notifications](https://airflow.apache.org/docs/apache-airflow/stable/howto/email-config.html)

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📄 License

This project is licensed under the MIT License.

---

**Happy Airflow-ing! 🌊**
