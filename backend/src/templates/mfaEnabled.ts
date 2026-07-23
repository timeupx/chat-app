export const mfaEnabledTemplate = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Two-Factor Authentication Enabled - Nexweb</title>
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
                            <h2 style="margin-top: 0; margin-bottom: 20px; color: #333333; font-size: 24px;">Two-Factor Authentication Enabled</h2>
                            <p style="margin-bottom: 25px; font-size: 16px; line-height: 1.5; color: #555555;">
                                Hello {name},
                            </p>
                            <p style="margin-bottom: 25px; font-size: 16px; line-height: 1.5; color: #555555;">
                                This is a confirmation that two-factor authentication (2FA) has been successfully enabled on your Nexweb account.
                            </p>
                            
                            <!-- 2FA Success Message Box -->
                            <div style="background-color: #f0f9f1; border-radius: 8px; padding: 20px; text-align: center; margin: 30px 0; border: 1px solid #d1e7d7;">
                                <div style="margin-bottom: 15px;">
                                    <svg width="60" height="60" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                                        <circle cx="12" cy="12" r="10" fill="#056A1E" />
                                        <path d="M8 12L11 15L16 9" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
                                    </svg>
                                </div>
                                <p style="margin: 0; font-size: 18px; font-weight: 600; color: #056A1E;">
                                    Your account is now more secure!
                                </p>
                                <p style="margin: 10px 0 0; font-size: 14px; color: #666666;">You will now need to enter a verification code when signing in</p>
                            </div>
                            
                            <p style="margin-bottom: 25px; font-size: 16px; line-height: 1.5; color: #555555;">
                                With two-factor authentication, your account has an extra layer of security. Each time you sign in, you'll need to provide both your password and a verification code.
                            </p>
                            
                            <p style="margin-bottom: 25px; font-size: 16px; line-height: 1.5; color: #555555;">
                                If you did not enable two-factor authentication on your account, please contact our support team immediately.
                            </p>
                            
                            <!-- Button -->
                            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
                                <tr>
                                    <td align="center" style="padding: 20px 0 30px;">
                                        <a href="#" style="display: inline-block; background-color: #056A1E; color: #ffffff; text-decoration: none; font-weight: 600; padding: 12px 30px; border-radius: 4px; font-size: 16px;">Manage Security Settings</a>
                                    </td>
                                </tr>
                            </table>
                        </td>
                    </tr>
                    
                    <!-- Footer -->
                    <tr>
                        <td style="background-color: #f7f7f7; padding: 30px 40px; text-align: center; border-top: 1px solid #eeeeee;">
                            <p style="margin: 0 0 15px; font-size: 14px; color: #666666;">
                                &copy; 2025 Nexweb. All rights reserved.
                            </p>
                            <p style="margin: 0; font-size: 14px; color: #666666;">
                                If you have any questions, please contact our <a href="#" style="color: #056A1E; text-decoration: none;">support team</a>.
                            </p>
                            <div style="margin-top: 20px;">
                                <a href="#" style="display: inline-block; margin: 0 8px; color: #056A1E; text-decoration: none; font-size: 14px;">Privacy Policy</a>
                                <a href="#" style="display: inline-block; margin: 0 8px; color: #056A1E; text-decoration: none; font-size: 14px;">Terms of Service</a>
                                <a href="#" style="display: inline-block; margin: 0 8px; color: #056A1E; text-decoration: none; font-size: 14px;">Unsubscribe</a>
                            </div>
                        </td>
                    </tr>
                </table>
                
                <!-- Alert Banner -->
                <table role="presentation" width="600" cellspacing="0" cellpadding="0" border="0" style="margin-top: 20px;">
                    <tr>
                        <td style="background-color: #FFF5F5; border-left: 4px solid #FA2F2B; padding: 15px 20px; border-radius: 4px;">
                            <p style="margin: 0; font-size: 14px; line-height: 1.5; color: #333333;">
                                <span style="color: #FA2F2B; font-weight: 600;">Security Notice:</span> Nexweb will never ask for your password or personal financial information via email.
                            </p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>`;
