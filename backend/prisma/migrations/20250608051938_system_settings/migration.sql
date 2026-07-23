/*
  Warnings:

  - You are about to drop the `Page` table. If the table is not empty, all the data it contains will be lost.

*/
-- DropTable
DROP TABLE "Page";

-- CreateTable
CREATE TABLE "SystemSettings" (
    "id" TEXT NOT NULL,
    "metaTitle" TEXT,
    "metaDescription" TEXT,
    "allowSignup" BOOLEAN NOT NULL DEFAULT true,
    "maintenanceMode" BOOLEAN NOT NULL DEFAULT false,
    "contactId" TEXT,
    "intigrationId" TEXT,
    "analyticsSeoId" TEXT,

    CONSTRAINT "SystemSettings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Contact" (
    "id" TEXT NOT NULL,
    "email" TEXT,
    "phone" TEXT,
    "address" TEXT,
    "facebook" TEXT,
    "x" TEXT,
    "instagram" TEXT,
    "youtube" TEXT,

    CONSTRAINT "Contact_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Intigrations" (
    "id" TEXT NOT NULL,
    "smsApiKey" TEXT,
    "emailApiKey" TEXT,

    CONSTRAINT "Intigrations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AnalyticsSeo" (
    "id" TEXT NOT NULL,
    "gatId" TEXT,
    "gtmId" TEXT,
    "pixelId" TEXT,

    CONSTRAINT "AnalyticsSeo_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "SystemSettings_contactId_key" ON "SystemSettings"("contactId");

-- CreateIndex
CREATE UNIQUE INDEX "SystemSettings_intigrationId_key" ON "SystemSettings"("intigrationId");

-- CreateIndex
CREATE UNIQUE INDEX "SystemSettings_analyticsSeoId_key" ON "SystemSettings"("analyticsSeoId");

-- AddForeignKey
ALTER TABLE "SystemSettings" ADD CONSTRAINT "SystemSettings_contactId_fkey" FOREIGN KEY ("contactId") REFERENCES "Contact"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SystemSettings" ADD CONSTRAINT "SystemSettings_intigrationId_fkey" FOREIGN KEY ("intigrationId") REFERENCES "Intigrations"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SystemSettings" ADD CONSTRAINT "SystemSettings_analyticsSeoId_fkey" FOREIGN KEY ("analyticsSeoId") REFERENCES "AnalyticsSeo"("id") ON DELETE SET NULL ON UPDATE CASCADE;
