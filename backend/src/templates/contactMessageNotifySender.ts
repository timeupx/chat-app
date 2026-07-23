export const StoreContactConfirmationTemplate = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>We've Received Your Message - Nexweb</title>
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
                            <h2 style="margin-top: 0; margin-bottom: 20px; color: #333333; font-size: 24px;">Thank You for Contacting Us</h2>
                            <p style="margin-bottom: 25px; font-size: 16px; line-height: 1.5; color: #555555;">
                                Hello {name},
                            </p>
                            <p style="margin-bottom: 25px; font-size: 16px; line-height: 1.5; color: #555555;">
                                We've received your message and wanted to let you know that it's in good hands. A member of our team will review your inquiry and get back to you as soon as possible.
                            </p>
                            
                            <!-- Confirmation Box -->
                            <div style="background-color: #f0f9f1; border-radius: 8px; padding: 25px; margin: 30px 0; border: 1px solid #d1e7d7;">
                                <div style="text-align: center; margin-bottom: 20px;">
                                    <svg width="60" height="60" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                                        <circle cx="12" cy="12" r="10" fill="#056A1E" />
                                        <path d="M8 12L11 15L16 9" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
                                    </svg>
                                    <p style="margin: 10px 0 0; font-size: 18px; font-weight: 600; color: #056A1E;">
                                        Message Successfully Received
                                    </p>
                                </div>
                                
                                <!-- Message Summary -->
                                <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
                                    <tr>
                                        <!-- Subject and Date in first row -->
                                        <td width="50%" style="padding-bottom: 15px; padding-right: 10px; vertical-align: top;">
                                            <p style="margin: 0 0 5px; font-size: 14px; font-weight: 600; color: #666666;">Subject:</p>
                                            <p style="margin: 0; font-size: 16px; color: #333333;">{subject}</p>
                                        </td>
                                        <td width="50%" style="padding-bottom: 15px; padding-left: 10px; vertical-align: top;">
                                            <p style="margin: 0 0 5px; font-size: 14px; font-weight: 600; color: #666666;">Date Received:</p>
                                            <p style="margin: 0; font-size: 16px; color: #333333;">{date}</p>
                                        </td>
                                    </tr>
                                </table>
                            </div>
                            
                            <p style="margin-bottom: 15px; font-size: 16px; line-height: 1.5; color: #555555;">
                                <strong>What happens next?</strong>
                            </p>
                            <p style="margin-bottom: 25px; font-size: 16px; line-height: 1.5; color: #555555;">
                                Our team typically responds within 1-2 business days. During busy periods, it might take a little longer, but rest assured that we're working on addressing your inquiry.
                            </p>
                            
                            
                            <!-- Button -->
                            
                        </td>
                    </tr>
                    
                    <!-- Footer -->
                    <tr>
                        <td style="background-color: #f7f7f7; padding: 30px 40px; text-align: center; border-top: 1px solid #eeeeee;">
                            <p style="margin: 0 0 15px; font-size: 14px; color: #666666;">
                                &copy; 2024 Nexweb. All rights reserved.
                            </p>
                            <p style="margin: 0; font-size: 14px; color: #666666;">
                                This is an automated confirmation. Please don't reply directly to this email.
                            </p>
                            <div style="margin-top: 20px;">
                                <a href="#" style="display: inline-block; margin: 0 8px; color: #056A1E; text-decoration: none; font-size: 14px;">Privacy Policy</a>
                                <a href="#" style="display: inline-block; margin: 0 8px; color: #056A1E; text-decoration: none; font-size: 14px;">Terms of Service</a>
                                <a href="#" style="display: inline-block; margin: 0 8px; color: #056A1E; text-decoration: none; font-size: 14px;">Help Center</a>
                            </div>
                        </td>
                    </tr>
                </table>
                
               
            </td>
        </tr>
    </table>
</body>
</html>`;
