//! Module doc with Markdown-sensitive text: `code` | table.

pub const LIMIT: usize = 7;
pub static NAME: &str = "crate";

pub mod nested {
    pub struct Unit;
    pub struct Tuple(pub i32, pub i32);
    pub struct Record {
        pub value: i32,
    }

    pub enum Choice {
        First,
        Second(i32),
        Third { label: &'static str },
    }

    pub trait Render {
        fn render(&self);
        fn label(&self) -> &'static str {
            "label"
        }
    }

    impl Record {
        pub fn new(value: i32) -> Self {
            Self { value }
        }

        pub fn value(&self) -> i32 {
            self.value
        }
    }

    fn helper() {}
}

pub fn top_function() {}

mod external;

fn r#async() {}

const MARKDOWN_NAME: &str = "`code` | table";
