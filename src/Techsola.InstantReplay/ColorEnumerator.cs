namespace Techsola.InstantReplay
{
    internal unsafe ref struct ColorEnumerator
    {
        private unsafe byte* next;
        private unsafe byte* lineEnd;
        private readonly unsafe byte* imageEnd;
        private readonly uint stride;
        private readonly uint strideSkip;

        public unsafe ColorEnumerator(byte* start, uint width, uint stride, uint height)
        {
            next = start - 3;
            lineEnd = start + (width * 3);
            this.stride = stride;
            strideSkip = stride - (width * 3);
            imageEnd = start + (height * stride) - strideSkip;
        }

        /// <summary>
        /// Returns a pointer to the 'next' 3-byte RGB structure.
        /// </summary>
        public RGB* Current
        {
            get
            {
                unsafe
                {
                    return (RGB*)(next);
                }
            }
        }

        public bool MoveNext()
        {
            unsafe
            {
                next += 3;
                if (next >= lineEnd)
                {
                    if (next >= imageEnd) return false;
                    next += strideSkip;
                    lineEnd += stride;
                }
                return true;
            }
        }
    }
}
