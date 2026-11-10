@echo off
echo Lancement de TOIT D’OR (Web - connecte au backend localhost:3000)...
flutter run -d chrome --dart-define=API_URL=http://localhost:3000/api
pause