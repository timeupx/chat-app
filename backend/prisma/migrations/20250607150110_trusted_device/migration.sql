-- AlterTable
ALTER TABLE "TrustedDevice" ADD COLUMN     "browser" TEXT,
ADD COLUMN     "location" TEXT,
ALTER COLUMN "ip" DROP NOT NULL,
ALTER COLUMN "userAgent" DROP NOT NULL;
