import { hasCrisisSignal } from './cbt-templates';

describe('hasCrisisSignal', () => {
  it.each([
    'Mình muốn chết',
    'dạo này KHÔNG MUỐN SỐNG nữa',
    'muon chet qua',
    'tu sat cho xong',
    'khong con muon song',
    'I want to end it all',
  ])('flags %p', (text) => expect(hasCrisisSignal(text)).toBe(true));

  it.each([
    'Cứ từ từ rồi mọi chuyện sẽ ổn',
    'cu tu tu thoi',
    'Mai mình đi tư vấn tâm lý',
    'mai di tu van tam ly',
    'Hôm nay mình cắt tóc',
    'catay', // không khớp giữa một từ
    '',
  ])('does not flag %p', (text) => expect(hasCrisisSignal(text)).toBe(false));

  it('checks every text passed in', () => {
    expect(hasCrisisSignal('Hôm nay mệt', 'muon chet')).toBe(true);
  });
});
