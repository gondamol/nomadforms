# NomadForms REST API

RESTful API for survey data collection and management.

## 🚀 Quick Start

### Install Dependencies

```R
install.packages(c("plumber", "DBI", "RPostgres", "jsonlite", "uuid"))
```

### Configure Database

Create a `.env` file in the `api/` directory:

```bash
DATABASE_URL=postgresql://user:password@localhost:5432/nomadforms
API_PORT=8080
API_HOST=0.0.0.0
```

Or set individual environment variables:

```bash
export DB_NAME=nomadforms
export DB_HOST=localhost
export DB_PORT=5432
export DB_USER=postgres
export DB_PASSWORD=password
```

### Run the API Server

```bash
cd api
Rscript run_api.R
```

The API will be available at `http://localhost:8080`

### API Documentation

Interactive Swagger documentation is available at:
`http://localhost:8080/__docs__/`

## 📡 API Endpoints

### Health Check

```http
GET /api/health
```

Response:
```json
{
  "status": "ok",
  "message": "NomadForms API is running",
  "version": "1.0.0",
  "timestamp": "2025-11-01T12:00:00Z"
}
```

### Surveys

#### Get All Surveys

```http
GET /api/surveys
```

#### Get Survey by ID

```http
GET /api/surveys/{survey_id}
```

#### Create Survey

```http
POST /api/surveys
Content-Type: application/json

{
  "title": "My Survey",
  "description": "Survey description"
}
```

### Responses

#### Submit Response

```http
POST /api/responses
Content-Type: application/json

{
  "survey_id": "uuid",
  "session_id": "uuid",
  "responses": {
    "q1": "answer1",
    "q2": "answer2"
  },
  "device_info": {
    "platform": "mobile",
    "os": "Android"
  },
  "is_offline": false
}
```

#### Get Survey Responses

```http
GET /api/surveys/{survey_id}/responses?format=json
```

Supported formats: `json`, `csv`, `xlsx`

#### Batch Sync (Offline Responses)

```http
POST /api/sync
Content-Type: application/json

{
  "responses": [
    {
      "response_id": "uuid",
      "survey_id": "uuid",
      "session_id": "uuid",
      "responses": {...},
      "submitted_at": "2025-11-01T12:00:00Z"
    }
  ]
}
```

### Analytics

#### Get Survey Analytics

```http
GET /api/surveys/{survey_id}/analytics
```

Response:
```json
{
  "success": true,
  "data": {
    "total_responses": 150,
    "offline_responses": 45,
    "online_responses": 105,
    "responses_by_day": [
      {"date": "2025-11-01", "count": 25},
      {"date": "2025-10-31", "count": 30}
    ]
  }
}
```

### Export

#### Export Survey Data

```http
GET /api/surveys/{survey_id}/export?format=csv
```

Supported formats: `csv`, `stata`, `spss`, `excel`, `r`

## 🔐 Authentication

Authentication is planned for Phase 4. Currently, the API is open for development.

## 🌐 CORS

CORS is enabled for all origins (`*`). In production, configure specific allowed origins.

## 📊 Rate Limiting

Rate limiting is planned for production deployment.

## 🐛 Error Handling

All endpoints return standardized error responses:

```json
{
  "success": false,
  "error": "Error message here"
}
```

HTTP status codes:
- `200` - Success
- `400` - Bad Request
- `404` - Not Found
- `500` - Internal Server Error

## 🧪 Testing

```bash
# Health check
curl http://localhost:8080/api/health

# Create survey
curl -X POST http://localhost:8080/api/surveys \
  -H "Content-Type: application/json" \
  -d '{"title": "Test Survey", "description": "Test"}'

# Get surveys
curl http://localhost:8080/api/surveys
```

## 📦 Docker Deployment

```dockerfile
FROM rocker/r-ver:4.3

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libpq-dev \
    libcurl4-openssl-dev \
    libssl-dev

# Install R packages
RUN R -e "install.packages(c('plumber', 'DBI', 'RPostgres', 'jsonlite', 'uuid'))"

# Copy API code
WORKDIR /app
COPY api/ /app/

# Expose port
EXPOSE 8080

# Run API
CMD ["Rscript", "run_api.R"]
```

## 🚀 Production Deployment

### Heroku

1. Create `Aptfile` for system dependencies
2. Add R buildpack
3. Set environment variables
4. Deploy

### AWS Lambda

Use `plumber` with AWS Lambda adapter

### Docker + Kubernetes

Use the provided Dockerfile with Kubernetes deployment manifests

## 📝 License

MIT License - see LICENSE file

