import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { v4 as uuid } from 'uuid';
import { Post } from './entities/post.entity';
import { PostLike } from './entities/post-like.entity';
import { CreatePostDto } from './dto/create-post.dto';
import { UpdatePostDto } from './dto/update-post.dto';
import { User } from '../users/entities/user.entity';
import { pageParams } from '../common/pagination';

@Injectable()
export class PostsService {
  constructor(
    @InjectRepository(Post)
    private postsRepository: Repository<Post>,
    @InjectRepository(PostLike)
    private postLikesRepository: Repository<PostLike>,
  ) {}

  async create(createPostDto: CreatePostDto, author: User): Promise<any> {
    const post = this.postsRepository.create({
      id: uuid(),
      ...createPostDto,
      author,
      authorId: author.id,
    });

    await this.postsRepository.save(post);
    return this.toPostResponse(post);
  }

  async findAll(pageQuery?: unknown, limitQuery?: unknown): Promise<any> {
    const { page, limit, skip } = pageParams(pageQuery, limitQuery);
    const [posts, total] = await this.postsRepository.findAndCount({
      relations: ['author'],
      order: { createdAt: 'DESC' },
      skip,
      take: limit,
    });

    return {
      data: posts.map((post) => this.toPostResponse(post)),
      total,
      page,
      limit,
      pages: Math.ceil(total / limit),
    };
  }

  async findById(id: string): Promise<any> {
    const post = await this.postsRepository.findOne({
      where: { id },
      relations: ['author'],
    });

    if (!post) {
      throw new NotFoundException('Bài viết không tồn tại');
    }

    return this.toPostResponse(post);
  }

  async update(id: string, updatePostDto: UpdatePostDto, user: User): Promise<any> {
    const post = await this.postsRepository.findOne({ where: { id } });

    if (!post) {
      throw new NotFoundException('Bài viết không tồn tại');
    }

    if (post.authorId !== user.id) {
      throw new ForbiddenException('Bạn không có quyền sửa bài viết này');
    }

    Object.assign(post, updatePostDto);
    await this.postsRepository.save(post);

    return this.toPostResponse(post);
  }

  async delete(id: string, user: User): Promise<void> {
    const post = await this.postsRepository.findOne({ where: { id } });

    if (!post) {
      throw new NotFoundException('Bài viết không tồn tại');
    }

    if (post.authorId !== user.id) {
      throw new ForbiddenException('Bạn không có quyền xoá bài viết này');
    }

    await this.postsRepository.delete(id);
  }

  async like(postId: string, user: User): Promise<any> {
    const post = await this.postsRepository.findOne({ where: { id: postId } });

    if (!post) {
      throw new NotFoundException('Bài viết không tồn tại');
    }

    // INSERT ... ON CONFLICT DO NOTHING: hai yêu cầu like song song chỉ tính một lần.
    const inserted = await this.postLikesRepository
      .createQueryBuilder()
      .insert()
      .values({ id: uuid(), postId, userId: user.id })
      .orIgnore()
      .execute();

    if ((inserted.raw as unknown[]).length > 0) {
      await this.postsRepository.increment({ id: postId }, 'likesCount', 1);
    }

    return this.findById(postId);
  }

  async unlike(postId: string, user: User): Promise<any> {
    const post = await this.postsRepository.findOne({ where: { id: postId } });

    if (!post) {
      throw new NotFoundException('Bài viết không tồn tại');
    }

    const like = await this.postLikesRepository.findOne({
      where: { postId, userId: user.id },
    });

    if (!like) {
      return this.toPostResponse(post);
    }

    const removed = await this.postLikesRepository.delete(like.id);
    if (removed.affected) {
      await this.postsRepository.decrement({ id: postId }, 'likesCount', 1);
    }

    return this.findById(postId);
  }

  private toPostResponse(post: Post): any {
    return {
      id: post.id,
      content: post.content,
      imageUrls: post.imageUrls,
      author: {
        id: post.author?.id,
        username: post.author?.username,
        displayName: post.author?.displayName,
        avatar: post.author?.avatar,
      },
      likesCount: post.likesCount,
      createdAt: post.createdAt,
      updatedAt: post.updatedAt,
    };
  }
}
