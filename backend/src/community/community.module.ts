import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { COMMUNITY_ENTITIES } from './community.entities';
import { CommunityService } from './community.service';
import { CommunityController } from './community.controller';

@Module({
  imports: [TypeOrmModule.forFeature(COMMUNITY_ENTITIES)],
  controllers: [CommunityController],
  providers: [CommunityService],
})
export class CommunityModule {}
