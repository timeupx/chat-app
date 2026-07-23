export const newLoginAlertTemplate = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>New Login Alert - Nexweb</title>
</head>
<body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f7f7f7; color: #333333;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
        <tr>
            <td align="center" style="padding: 20px 0;">
                <table role="presentation" width="600" cellspacing="0" cellpadding="0" border="0" style="background-color: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">
                    <!-- Header -->
                    <tr>
                        <td style="background-color: #056A1E; padding: 30px 40px; text-align: center;">
                            <h1 style="color: #ffffff; margin: 0; font-size: 28px; font-weight: 700;">Nexweb</h1>
                        </td>
                    </tr>
                    
                    <!-- Content -->
                    <tr>
                        <td style="padding: 40px;">
                            <h2 style="margin-top: 0; margin-bottom: 20px; color: #333333; font-size: 24px;">New Login Detected</h2>
                            
                            <!-- Simple Greeting -->
                            <p style="margin-bottom: 25px; font-size: 16px; line-height: 1.5; color: #555555;">
                                Hello {name},
                            </p>
                            
                            <p style="margin-bottom: 25px; font-size: 16px; line-height: 1.5; color: #555555;">
                                We detected a new login to your Nexweb account. For security purposes, we're notifying you of this recent account activity.
                            </p>
                            
                            <!-- Login Details Box -->
                            <div style="background-color: #f7f7f7; border-radius: 8px; padding: 25px; margin: 30px 0;">
                                <h3 style="margin-top: 0; margin-bottom: 15px; color: #056A1E; font-size: 18px;">Login Details</h3>
                                
                                <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="font-size: 15px; color: #555555;">
                                    <tr>
                                        <td style="padding: 8px 0; width: 140px; vertical-align: top;"><strong>Date & Time:</strong></td>
                                        <td style="padding: 8px 0;">{loginTime}</td>
                                    </tr>
                                    <tr>
                                        <td style="padding: 8px 0; width: 140px; vertical-align: top;"><strong>IP Address:</strong></td>
                                        <td style="padding: 8px 0;">{ipAddress}</td>
                                    </tr>
                                    <tr>
                                        <td style="padding: 8px 0; width: 140px; vertical-align: top;"><strong>Browser:</strong></td>
                                        <td style="padding: 8px 0;">{browser}</td>
                                    </tr>
                                    <tr>
                                        <td style="padding: 8px 0; width: 140px; vertical-align: top;"><strong>Device:</strong></td>
                                        <td style="padding: 8px 0;">{userAgent}</td>
                                    </tr>
                                    <tr>
                                        <td style="padding: 8px 0; width: 140px; vertical-align: top;"><strong>Location:</strong></td>
                                        <td style="padding: 8px 0;">{location}</td>
                                    </tr>
                                </table>
                            </div>
                            
                            <!-- Warning Box -->
                            <div style="background-color: #FFF5F5; border-left: 4px solid #FA2F2B; padding: 15px 20px; border-radius: 4px; margin-bottom: 25px;">
                                <p style="margin: 0; font-size: 15px; line-height: 1.5; color: #333333;">
                                    <span style="color: #FA2F2B; font-weight: 600;">Wasn't you?</span> If you didn't log in, someone else may have access to your account. Please secure your account immediately by changing your password.
                                </p>
                            </div>
                            
                            <!-- Single Button -->
                            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
                                <tr>
                                    <td align="center" style="padding: 20px 0;">
                                        <a href="#" style="display: inline-block; background-color: #FA2F2B; color: #ffffff; text-decoration: none; font-weight: 600; padding: 12px 30px; border-radius: 4px; font-size: 16px;">Secure My Account</a>
                                    </td>
                                </tr>
                            </table>
                            
                            <p style="margin-top: 25px; margin-bottom: 0; font-size: 16px; line-height: 1.5; color: #555555;">
                                If this was you, you can safely ignore this email. If you have any questions or concerns, please contact our support team immediately.
                            </p>
                        </td>
                    </tr>
                    
                    <!-- Footer -->
                    <tr>
                        <td style="background-color: #f7f7f7; padding: 30px 40px; text-align: center; border-top: 1px solid #eeeeee;">
                            <p style="margin: 0 0 15px; font-size: 14px; color: #666666;">
                                &copy; 2024 Nexweb. All rights reserved.
                            </p>
                            <p style="margin: 0; font-size: 14px; color: #666666;">
                                For security assistance, please contact our <a href="#" style="color: #056A1E; text-decoration: none;">support team</a>.
                            </p>
                            <div style="margin-top: 20px;">
                                <a href="#" style="display: inline-block; margin: 0 8px; color: #056A1E; text-decoration: none; font-size: 14px;">Privacy Policy</a>
                                <a href="#" style="display: inline-block; margin: 0 8px; color: #056A1E; text-decoration: none; font-size: 14px;">Terms of Service</a>
                                <a href="#" style="display: inline-block; margin: 0 8px; color: #056A1E; text-decoration: none; font-size: 14px;">Account Settings</a>
                            </div>
                        </td>
                    </tr>
                </table>
                
                <!-- Additional Info -->
                <table role="presentation" width="600" cellspacing="0" cellpadding="0" border="0" style="margin-top: 20px;">
                    <tr>
                        <td style="padding: 15px 20px; text-align: center;">
                            <p style="margin: 0; font-size: 13px; line-height: 1.5; color: #888888;">
                                This is an automated message. Please do not reply to this email. If you need assistance, please contact our support team.
                            </p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>`;
