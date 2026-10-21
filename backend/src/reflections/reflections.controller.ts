import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { ReflectionsService } from './reflections.service';
import {
  GenerateReflectionDto,
  RecommendExerciseDto,
  ReflectionFeedbackDto,
  SafetyCheckDto,
} from './dto/reflection.dto';
import { JwtGuard } from '../auth/guards/jwt.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';

@ApiTags('reflections')
@ApiBearerAuth()
@UseGuards(JwtGuard)
@Controller('reflections')
export class ReflectionsController {
  constructor(private reflectionsService: ReflectionsService) {}

  // Mỗi lần gọi có thể tốn phí nhà cung cấp AI; giới hạn chặt hơn mức chung.
  @Post('generate')
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Tạo phản tư CBT (AI nếu được cấu hình, nếu không dùng template)' })
  async generate(@CurrentUser() user: User, @Body() dto: GenerateReflectionDto) {
    return this.reflectionsService.generate(user, dto);
  }

  @Get('history')
  @ApiOperation({ summary: 'Lịch sử phản tư của tôi' })
  async history(@CurrentUser() user: User, @Query('limit') limit?: string) {
    return this.reflectionsService.history(user, limit);
  }

  @Get('insights')
  @ApiOperation({ summary: 'Tổng hợp xu hướng từ nhật ký của tôi' })
  async insights(
    @CurrentUser() user: User,
    @Query('startDate') startDate?: string,
    @Query('endDate') endDate?: string,
  ) {
    return this.reflectionsService.insights(user, startDate, endDate);
  }

  @Post('exercise')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Gợi ý bài tập theo cảm xúc' })
  recommendExercise(@Body() dto: RecommendExerciseDto) {
    return this.reflectionsService.recommendExercise(dto.emotionKey, dto.intensity);
  }

  @Post('safety-check')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Kiểm tra tín hiệu khủng hoảng trong văn bản' })
  safetyCheck(@Body() dto: SafetyCheckDto) {
    return this.reflectionsService.safetyCheck(dto.situation, dto.thought);
  }

  @Post(':id/feedback')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Phản hồi về một phản tư' })
  async feedback(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ReflectionFeedbackDto,
  ) {
    await this.reflectionsService.feedback(user, id, dto);
  }
}
