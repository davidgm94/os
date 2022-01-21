pub const Driver = struct
{
    pub fn init(self: *@This()) i32
    {
        _ = self;
        var a: i32 = 0;
        var b: i32 = 1;
        var c: i32 = if (b == 1) 1241 else 12;
        return a + b + c;
    }
};

pub var driver: Driver = undefined;
