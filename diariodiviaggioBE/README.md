# Diario di Viaggio - Travel Diary App

A full-stack travel diary application built with Angular frontend and .NET backend.

## 🌐 Live Demo

The frontend is deployed on GitHub Pages: [https://alessandroclima.github.io/diariodiviaggio/](https://alessandroclima.github.io/diariodiviaggio/)

## 🚀 Deployment

### Frontend (GitHub Pages)

The frontend is automatically deployed to GitHub Pages using GitHub Actions whenever changes are pushed to the `main` branch.

#### Manual Deployment

To deploy manually:

```bash
cd DiarioDiViaggioWeb
npm install
npm run deploy:ghpages
```

#### Local Development

```bash
cd DiarioDiViaggioWeb
npm install
npm start
```

The app will be available at `http://localhost:4200`

### Backend (.NET API)

The backend is deployed on Azure App Service at: `https://lericettedialeinborghese-gdfvh7ccgxc9a0e8.italynorth-01.azurewebsites.net`

#### Local Development

```bash
cd DiarioDiViaggioApi
dotnet restore
dotnet run
```

The API will be available at `http://localhost:5106`

## 🏗️ Architecture

- **Frontend**: Angular 16 with Bootstrap 5
- **Backend**: .NET 9 Web API
- **Database**: PostgreSQL
- **Authentication**: JWT tokens
- **Image Storage**: Database BLOB storage

## 📦 Features

- User authentication and registration
- Trip management
- Trip item creation with photos, ratings, and locations
- Luggage list management
- Responsive design
- Real-time image upload and display

## 🛠️ Technologies Used

### Frontend
- Angular 16
- TypeScript
- Bootstrap 5
- Bootstrap Icons
- RxJS

### Backend
- .NET 9
- Entity Framework Core
- PostgreSQL
- JWT Authentication
- AutoMapper

## 📝 Configuration

### Environment Files

- `environment.ts` - Development environment
- `environment.prod.ts` - Production environment
- `environment.github-pages.ts` - GitHub Pages specific environment

### API Endpoints

The frontend communicates with the backend through REST API endpoints:
- `/api/auth` - Authentication
- `/api/trip` - Trip management
- `/api/tripitem` - Trip items
- `/api/luggage` - Luggage management

## 🔧 Development Setup

1. Clone the repository
2. Set up the backend:
   ```bash
   cd DiarioDiViaggioApi
   dotnet restore
   dotnet ef database update
   dotnet run
   ```
3. Set up the frontend:
   ```bash
   cd DiarioDiViaggioWeb
   npm install
   npm start
   ```

## 📄 License

This project is private and for personal use.
