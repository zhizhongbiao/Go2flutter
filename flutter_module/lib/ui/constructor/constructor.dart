// class Student {
//   int age;
//   String name;
//
//   Student(this.age, this.name);
// }
//
// class Student1 {
//   int? age;
//   String? name;
//
//   Student1.anonymous() {
//     name = "匿名";
//     age = 0;
//   }
// }
//
// class Student3 {
//   int age;
//   String name;
//
//   Student3(int age, String name) : this.age = age, this.name = name {
//     /**
//      * 上面赋值先于构造函数执行；
//      */
//   }
// }
//
// class Student4 {
//   final int age;
//   final String name;
//
//   const Student4(this.age, this.name);
// }
//
// class Student5 {
//   final int age;
//   final String name;
//
//   Student5(this.age, this.name);
//
//   Student5.proxy() : this(1, "zzb");
// }
//
// class Student6 {
//   static final Student6 _instance = Student6._internal();
//
//   factory Student6() => _instance;
//
//   Student6._internal();
// }
