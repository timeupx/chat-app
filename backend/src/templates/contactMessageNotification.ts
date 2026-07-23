export const StoreContactNotificationTemplate = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>New Contact Form Submission - Nexweb</title>
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
                            <h2 style="margin-top: 0; margin-bottom: 20px; color: #333333; font-size: 24px;">New Contact Form Submission</h2>
                            <p style="margin-bottom: 25px; font-size: 16px; line-height: 1.5; color: #555555;">
                                A new message has been submitted through the contact form. Please find the details below:
                            </p>
                            
                            <!-- Contact Information Box -->
                            <div style="background-color: #f7f7f7; border-radius: 8px; padding: 25px; margin: 30px 0; border: 1px solid #eeeeee;">
                                <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
                                    <tr>
                                        <td style="padding-bottom: 15px;">
                                            <p style="margin: 0 0 5px; font-size: 14px; font-weight: 600; color: #666666;">Name:</p>
                                            <p style="margin: 0; font-size: 16px; color: #333333;">{name}</p>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td style="padding-bottom: 15px;">
                                            <p style="margin: 0 0 5px; font-size: 14px; font-weight: 600; color: #666666;">Email:</p>
                                            <p style="margin: 0; font-size: 16px; color: #333333;">{email}</p>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td style="padding-bottom: 15px;">
                                            <p style="margin: 0 0 5px; font-size: 14px; font-weight: 600; color: #666666;">Phone:</p>
                                            <p style="margin: 0; font-size: 16px; color: #333333;">{phone}</p>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td style="padding-bottom: 15px;">
                                            <p style="margin: 0 0 5px; font-size: 14px; font-weight: 600; color: #666666;">Subject:</p>
                                            <p style="margin: 0; font-size: 16px; color: #333333;">{subject}</p>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td>
                                            <p style="margin: 0 0 5px; font-size: 14px; font-weight: 600; color: #666666;">Message:</p>
                                            <div style="margin: 0; font-size: 16px; color: #333333; line-height: 1.6; background-color: #ffffff; padding: 15px; border-radius: 4px; border: 1px solid #eeeeee;">
                                                {message}
                                            </div>
                                        </td>
                                    </tr>
                                </table>
                            </div>
                            
                            <p style="margin-bottom: 25px; font-size: 16px; line-height: 1.5; color: #555555;">
                                Please respond to this inquiry at your earliest convenience.
                            </p>
                            
                           
                    
                    <!-- Footer -->
                    <tr>
                        <td style="background-color: #f7f7f7; padding: 30px 40px; text-align: center; border-top: 1px solid #eeeeee;">
                            <p style="margin: 0 0 15px; font-size: 14px; color: #666666;">
                                &copy; 2024 Nexweb. All rights reserved.
                            </p>
                            <p style="margin: 0; font-size: 14px; color: #666666;">
                                This is an automated message. Please do not reply directly to this email.
                            </p>
                            <div style="margin-top: 20px;">
                                <a href="#" style="display: inline-block; margin: 0 8px; color: #056A1E; text-decoration: none; font-size: 14px;">Admin Dashboard</a>
                                <a href="#" style="display: inline-block; margin: 0 8px; color: #056A1E; text-decoration: none; font-size: 14px;">Contact Settings</a>
                                <a href="#" style="display: inline-block; margin: 0 8px; color: #056A1E; text-decoration: none; font-size: 14px;">Help Center</a>
                            </div>
                        </td>
                    </tr>
                </table>
                
              
</body>
</html>`;
