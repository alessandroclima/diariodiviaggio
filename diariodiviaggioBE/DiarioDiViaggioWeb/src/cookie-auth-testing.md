# Cookie Authentication Testing Checklist

## Prerequisites
- Backend running on HTTPS (for production) or HTTP (for development)
- Frontend and backend URLs properly configured
- CORS enabled with AllowCredentials()

## Step-by-Step Testing

### 1. Environment Verification
```bash
# Check your backend is running on the correct port
# Verify the frontend environment.ts matches your backend URL
# Ensure both are using the same protocol (HTTP/HTTPS)
```

**Expected**: Frontend points to correct backend URL

### 2. Login Test
```typescript
// 1. Open browser developer tools
// 2. Go to Network tab
// 3. Login with valid credentials
// 4. Check the login response headers for:
//    - Set-Cookie: refreshToken=...; HttpOnly; SameSite=None; Path=/
// 5. Check console for debug messages
```

**Expected**: 
- Login successful
- Set-Cookie header present in response
- Console shows: "Setting refresh token cookie..."

### 3. Cookie Verification
```javascript
// In browser console after login:
document.cookie
// Should NOT show refreshToken (because it's HttpOnly)

// In Network tab, check subsequent requests have:
// Cookie: refreshToken=...
```

**Expected**: HttpOnly cookie sent with requests but not visible in document.cookie

### 4. Refresh Token Test
```typescript
// Option A: Wait for token to expire naturally
// Option B: Use the debug component to manually trigger refresh
// Option C: Manually call the refresh endpoint

// Check console for:
// - "Making refresh token request to..."
// - Backend debug output showing cookie reception
```

**Expected**: 
- Refresh request includes Cookie header
- Backend logs show cookie received
- New token returned and stored

### 5. Network Analysis
In browser dev tools > Network tab, check:

**Login Request:**
```
Request Headers:
  Origin: http://localhost:4200
  
Response Headers:
  Set-Cookie: refreshToken=...; HttpOnly; SameSite=None; Path=/; Expires=...
  Access-Control-Allow-Credentials: true
```

**Refresh Request:**
```
Request Headers:
  Cookie: refreshToken=...
  Origin: http://localhost:4200
  
Response Headers:
  Set-Cookie: refreshToken=...; HttpOnly; SameSite=None; Path=/; Expires=...
```

## Common Issues and Solutions

### Issue 1: "Refresh token not found"
**Cause**: Cookie not being sent
**Check**: 
- CORS AllowCredentials is true
- SameSite=None (for cross-origin)
- Secure flag matches protocol (false for HTTP development)
- Frontend uses withCredentials: true

### Issue 2: Cookie visible in document.cookie
**Cause**: HttpOnly not set correctly
**Fix**: Verify backend cookie options have HttpOnly: true

### Issue 3: Cookie not set after login
**Cause**: CORS or protocol mismatch
**Check**:
- Frontend and backend use same protocol (HTTP/HTTPS)
- CORS configuration includes frontend origin
- Browser security settings

### Issue 4: SameSite warnings in console
**Cause**: Browser rejecting cross-site cookies
**Fix**: Use SameSite=None with Secure=true (HTTPS only)

## Debug Commands

### Backend Debug (in AuthController)
The debug output should show:
```
=== Refresh Token Request Debug ===
Request Origin: http://localhost:4200
Request Host: localhost:5000
Available Cookies: refreshToken
Found refresh token cookie: abcd123456...
Successfully refreshed token and set new cookie
```

### Frontend Debug (in browser console)
```javascript
// Check current authentication state
localStorage.getItem('auth_token')

// Check visible cookies
document.cookie

// Check origin and protocol
window.location.origin
window.location.protocol
```

## Testing the Fix

1. **Clear all browser data** for localhost
2. **Login** and verify Set-Cookie header
3. **Check Network tab** for Cookie header in subsequent requests
4. **Trigger refresh** (manually or wait for expiration)
5. **Verify new token** received and stored
6. **Test API calls** work with refreshed token

## If Still Not Working

Add this temporary endpoint to AuthController for testing:
```csharp
[HttpGet("test-cookie")]
public ActionResult TestCookie()
{
    var cookie = Request.Cookies["refreshToken"];
    return Ok(new { 
        cookieExists = !string.IsNullOrEmpty(cookie),
        cookieValue = cookie?.Substring(0, Math.Min(10, cookie?.Length ?? 0)) + "...",
        allCookies = Request.Cookies.Keys.ToList(),
        origin = Request.Headers["Origin"].ToString(),
        userAgent = Request.Headers["User-Agent"].ToString()
    });
}
```

Then call it from frontend to see what cookies are being received.
