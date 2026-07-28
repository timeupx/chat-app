-- AlterTable
ALTER TABLE "LiveRoom" ADD COLUMN     "filterName" TEXT NOT NULL DEFAULT 'Natural',
ADD COLUMN     "slotCount" INTEGER NOT NULL DEFAULT 6;
