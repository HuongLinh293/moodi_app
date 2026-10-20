import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { v4 as uuid } from 'uuid';
import { Post } from './entities/post.entity';
import { PostLike } from './entities/post-like.entity';
import { CreatePostDto } from './dto/create-post.dto';
import { UpdatePostDto } from './dto/update-post.dto';
import { User } from '../users/entities/user.entity';

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

  async findAll(page = 1, limit = 10): Promise<any> {
    const [posts, total] = await this.postsRepository.findAndCount({
      relations: ['author', 'likes'],
      order: { createdAt: 'DESC' },
      skip: (page - 1) * limit,
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
      relations: ['author', 'likes'],
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

    // Check if already liked
    const existingLike = await this.postLikesRepository.findOne({
      where: { postId, userId: user.id },
    });

    if (existingLike) {
      return this.toPostResponse(post);
    }

    // Create like
    const like = this.postLikesRepository.create({
      id: uuid(),
      post,
      postId,
      user,
      userId: user.id,
    });

    await this.postLikesRepository.save(like);

    // Update likes count
    post.likesCount++;
    await this.postsRepository.save(post);

    return this.toPostResponse(post);
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

    await this.postLikesRepository.delete(like.id);

    // Update likes count
    post.likesCount--;
    await this.postsRepository.save(post);

    return this.toPostResponse(post);
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
