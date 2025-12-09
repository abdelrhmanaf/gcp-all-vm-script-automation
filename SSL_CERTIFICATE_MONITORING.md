# SSL Certificate Monitoring & Renewal Documentation

## Overview

This document explains the automated SSL certificate renewal and monitoring system for **nelc.gov.sa** domain. You have been added to the notification channel and will receive alerts about certificate status.

---

## 🔔 What Notifications Will You Receive?

You will receive email notifications in the following scenarios:

### 1. **WARNING Alert** (30 Days Before Expiration)
- **When**: Certificate has 30 days or less until expiration
- **Severity**: Warning
- **What It Means**: Early heads-up that certificate is approaching expiration
- **Action Required**: None immediately, but be aware renewal is upcoming

### 2. **CRITICAL Alert** (7 Days Before Expiration)
- **When**: Certificate has 7 days or less until expiration
- **Severity**: Critical
- **What It Means**: Certificate is expiring soon and renewal may have failed
- **Action Required**: **IMMEDIATE** - Investigate why automatic renewal failed

### 3. **Renewal Success Notifications** (INFO)
- **When**: Certificate renewal completes successfully
- **Severity**: Info
- **What It Means**: System is working correctly
- **Action Required**: None - informational only

### 4. **Renewal Failure Notifications** (ERROR)
- **When**: Automatic renewal attempt fails
- **Severity**: Error
- **What It Means**: Renewal process encountered an error
- **Action Required**: Check logs and troubleshoot

---

## 🤖 How the Automation Works

### Automatic Renewal
- **Schedule**: Runs daily at 3:00 AM UTC
- **Tool**: Certbot (Let's Encrypt)
- **Process**: 
  1. Certbot checks if renewal is needed (certificates expiring in < 30 days)
  2. If needed, attempts to renew certificate
  3. On success, reloads web server configuration
  4. Logs all events to Google Cloud Logging

### Certificate Monitoring
- **Schedule**: Runs daily at 6:00 AM UTC
- **Process**:
  1. Checks certificate expiration date
  2. Calculates days until expiration
  3. Logs status to Cloud Logging
  4. Triggers alerts if thresholds are met

### Server Configuration
- **Deploy Hook**: Automatically reloads Nginx/Apache after successful renewal
- **No Downtime**: Certificate updates happen seamlessly

---

## 📊 Monitoring Dashboard

### View Logs in Google Cloud Console

1. **Go to Cloud Logging**:
   ```
   https://console.cloud.google.com/logs
   ```

2. **Filter for SSL Events**:
   ```
   resource.type="gce_instance"
   jsonPayload.component="ssl-certificate"
   ```

3. **View Logs by Severity**:
   - **INFO**: Successful renewals, status checks
   - **WARNING**: Certificates approaching expiration
   - **ERROR**: Renewal failures, configuration issues

---

## ⚠️ Alert Response Guide

### When You Receive a WARNING Alert (30 Days)

**Expected**: This is normal and means the system is monitoring correctly.

✅ **Actions**:
1. No immediate action required
2. Monitor for INFO logs confirming automatic renewal
3. Watch for follow-up notifications

### When You Receive a CRITICAL Alert (7 Days)

**Unexpected**: Automatic renewal should have renewed it already.

🚨 **URGENT Actions**:

1. **Check Renewal Logs**:
   ```bash
   sudo journalctl -u certbot-renew.timer
   sudo tail -100 /var/log/letsencrypt/letsencrypt.log
   ```

2. **Manually Attempt Renewal**:
   ```bash
   sudo certbot renew --dry-run  # Test first
   sudo certbot renew --force-renewal  # If test passes
   ```

3. **Check Certificate Status**:
   ```bash
   sudo certbot certificates
   ```

4. **Verify Domain Accessibility**:
   - Ensure `nelc.gov.sa` is accessible from internet
   - Check firewall rules allow HTTP (80) and HTTPS (443)
   - Verify DNS is pointing to correct server

5. **Check for Errors**:
   - Rate limiting from Let's Encrypt
   - Domain validation failures
   - Web server configuration issues

### When You Receive a RENEWAL FAILURE Alert

🔧 **Troubleshooting Steps**:

1. **Review Error Logs**:
   ```bash
   # Check certbot logs
   sudo tail -50 /var/log/letsencrypt/letsencrypt.log
   
   # Check Cloud Logging
   gcloud logging read "resource.type=gce_instance AND jsonPayload.component=ssl-certificate AND severity=ERROR" --limit 10
   ```

2. **Common Issues**:

   **Issue**: Rate Limiting
   - **Symptom**: "too many certificates already issued"
   - **Solution**: Wait for rate limit to reset (weekly limit)

   **Issue**: Domain Validation Failed
   - **Symptom**: "Failed authorization procedure"
   - **Solution**: 
     - Verify domain DNS points to server
     - Check port 80 is accessible
     - Ensure `.well-known/acme-challenge/` is accessible

   **Issue**: Web Server Not Reloading
   - **Symptom**: Certificate renewed but old cert still served
   - **Solution**: Manually reload web server
     ```bash
     sudo systemctl reload nginx  # or apache2
     ```

3. **Manual Renewal**:
   ```bash
   sudo certbot renew --force-renewal --deploy-hook "systemctl reload nginx"
   ```

---

## 🛠 Useful Commands

### Check Certificate Details
```bash
# View all certificates
sudo certbot certificates

# Check certificate expiration from file
sudo openssl x509 -in /etc/letsencrypt/live/nelc.gov.sa/cert.pem -noout -dates

# Check certificate from domain
echo | openssl s_client -servername nelc.gov.sa -connect nelc.gov.sa:443 2>/dev/null | openssl x509 -noout -dates
```

### Test Renewal Process
```bash
# Dry run (doesn't actually renew)
sudo certbot renew --dry-run

# Force renewal (use sparingly)
sudo certbot renew --force-renewal
```

### View Renewal Timer Status
```bash
# Check if automatic renewal is scheduled
sudo systemctl status certbot-renew.timer

# View when next renewal will run
sudo systemctl list-timers certbot-renew.timer
```

### Check Cloud Logging
```bash
# Recent SSL certificate logs
gcloud logging read "resource.type=gce_instance AND jsonPayload.component=ssl-certificate" --limit 20 --format json

# Only errors
gcloud logging read "resource.type=gce_instance AND jsonPayload.component=ssl-certificate AND severity=ERROR" --limit 10
```

---

## 📞 Escalation Process

### Level 1: Self-Service (You)
- Check logs and alerts
- Attempt manual renewal
- Verify domain/DNS configuration

### Level 2: Infrastructure Team
If self-service doesn't resolve:
- Contact infrastructure team
- Provide error logs
- Share alert screenshots

### Level 3: Emergency (Certificate Expired)
If certificate has expired:
- **Impact**: Users will see SSL warnings, site may be inaccessible
- **Action**: Immediately contact on-call engineer
- **Temporary Fix**: May need to temporarily disable HTTPS or use emergency certificate

---

## 🔍 Monitoring Best Practices

### Regular Checks (Monthly)
1. Verify certificate has > 60 days validity
2. Review renewal logs for any warnings
3. Confirm monitoring alerts are working

### After Receiving Alerts
1. Don't ignore WARNING alerts - track that renewal happens
2. CRITICAL alerts require same-day investigation
3. Document any manual interventions

### Emergency Contacts
- **Primary**: [Your Infrastructure Team Contact]
- **Secondary**: [Backup Contact]
- **After Hours**: [On-Call Rotation]

---

## 📝 Certificate Details

- **Domain**: nelc.gov.sa
- **Certificate Authority**: Let's Encrypt
- **Validity Period**: 90 days
- **Renewal Window**: 30 days before expiration
- **Automatic Renewal Time**: Daily at 3:00 AM UTC
- **Certificate Location**: `/etc/letsencrypt/live/nelc.gov.sa/`

---

## 🎯 Quick Reference

| Alert Type | Urgency | Response Time | Action |
|------------|---------|---------------|--------|
| INFO (Renewal Success) | None | N/A | No action needed |
| WARNING (30 days) | Low | Within 3 days | Monitor for renewal |
| CRITICAL (7 days) | High | Same day | Immediate investigation |
| ERROR (Renewal Failed) | High | Same day | Troubleshoot and fix |

---

## 📚 Additional Resources

- **Let's Encrypt Documentation**: https://letsencrypt.org/docs/
- **Certbot Documentation**: https://eff-certbot.readthedocs.io/
- **Google Cloud Logging**: https://cloud.google.com/logging/docs
- **Google Cloud Monitoring**: https://cloud.google.com/monitoring/docs

---

## ✅ Summary

**What you need to know**:
1. You'll receive email alerts about SSL certificate status
2. Most renewals happen automatically - no action needed
3. WARNING alerts (30 days) are informational
4. CRITICAL alerts (7 days) require immediate attention
5. Use this guide to troubleshoot issues

**Key Takeaway**: The system is designed to work automatically. You're receiving notifications to ensure nothing falls through the cracks. Most of the time, you'll just see INFO messages confirming successful renewals.

---

*Last Updated: 2025-12-09*  
*Maintained by: Infrastructure Team*
