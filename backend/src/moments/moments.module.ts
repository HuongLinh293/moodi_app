import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { GardenMoment } from './entities/garden-moment.entity';
import { MomentsService } from './moments.service';
import { MomentsController } from './moments.controller';

@Module({
  imports: [TypeOrmModule.forFeature([GardenMoment])],
  controllers: [MomentsController],
  providers: [MomentsService],
  exports: [TypeOrmModule],
})
export class MomentsModule {}
