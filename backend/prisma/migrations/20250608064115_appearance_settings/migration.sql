/*
  Warnings:

  - A unique constraint covering the columns `[appearanceId]` on the table `SystemSettings` will be added. If there are existing duplicate values, this will fail.

*/
-- AlterTable
ALTER TABLE "SystemSettings" ADD COLUMN     "appearanceId" TEXT;

-- CreateTable
CREATE TABLE "Appearance" (
    "id" TEXT NOT NULL,
    "logo" TEXT,
    "favicon" TEXT,
    "theme" TEXT,
    "themeMode" TEXT,

    CONSTRAINT "Appearance_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "SystemSettings_appearanceId_key" ON "SystemSettings"("appearanceId");

-- AddForeignKey
ALTER TABLE "SystemSettings" ADD CONSTRAINT "SystemSettings_appearanceId_fkey" FOREIGN KEY ("appearanceId") REFERENCES "Appearance"("id") ON DELETE SET NULL ON UPDATE CASCADE;
