@echo off
echo Lancement de VelQix (Web - connecte au backend localhost:3000)...
flutter run -d chrome --dart-define=API_URL=http://localhost:3000/api
pause