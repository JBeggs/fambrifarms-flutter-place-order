# 📱 Flutter Production Setup

## 🎯 **Backend URL Updated!**

Your Flutter app is now configured to connect to your PythonAnywhere backend:
**`https://fambridevops.pythonanywhere.com/api`**

## 🔧 **Environment Configuration**

### Option 1: Use Default Configuration (Recommended)
The app now defaults to your production backend. Just run:
```bash
flutter run
```

### Option 2: Use Environment Files
```bash
# For production
cp environment.production .env
flutter run

# For development (local backend)
cp environment.development .env
flutter run
```

### Option 3: Runtime Environment Variables
```bash
# Production
flutter run --dart-define=DJANGO_URL=https://fambridevops.pythonanywhere.com/api

# Development
flutter run --dart-define=DJANGO_URL=http://localhost:8000/api
```

## 🚀 **Testing Your Production Setup**

1. **Start Flutter App**:
   ```bash
   cd place-order-final
   flutter run
   ```

2. **Test Key Features**:
   - [ ] Login with: `admin@fambrifarms.co.za` / `defaultpassword123`
   - [ ] View products list
   - [ ] Check orders
   - [ ] Test WhatsApp messages
   - [ ] Verify procurement dashboard
   - [ ] Test customer management

3. **Check API Connection**:
   - Look for successful API calls in Flutter logs
   - Verify no CORS errors in browser console (if web)
   - Test authentication flow

## 🌐 **Web Deployment (Optional)**

If you want to deploy Flutter web:

1. **Build for Web**:
   ```bash
   flutter build web --dart-define=DJANGO_URL=https://fambridevops.pythonanywhere.com/api
   ```

2. **Deploy to Vercel/Netlify**:
   - Upload `build/web/` folder
   - Configure environment variables if needed

## 🔍 **Troubleshooting**

### CORS Issues
If you get CORS errors, verify your backend `.env` includes:
```
CORS_ALLOWED_ORIGINS=https://your-flutter-domain.com,http://localhost:3000
```

### Authentication Issues
- Clear app data/cache
- Check token storage in SharedPreferences
- Verify backend `/api/auth/login/` is accessible

### API Connection Issues
- Test backend directly: `https://fambridevops.pythonanywhere.com/api/products/`
- Check network connectivity
- Verify SSL certificate

## ✅ **Success Indicators**

- [ ] App loads without errors
- [ ] Login works successfully
- [ ] Data loads from production backend
- [ ] All CRUD operations function
- [ ] No CORS or network errors

## 🎉 **You're Ready!**

Your Flutter app is now configured for production! 🚀

**Backend**: `https://fambridevops.pythonanywhere.com/api`  
**Default Environment**: Production  
**Authentication**: Ready  
**CORS**: Configured  
